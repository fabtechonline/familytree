-- Billing + admin foundation: editable plan pricing, per-family subscription
-- state, app settings, family suspension, member limits, and the super-admin
-- RPCs to manage them. Payment rails (Paystack/Play/Apple) plug into this later.

-- ============ plans: editable fixed-tier pricing ============
create table if not exists public.plans (
  key text primary key,                    -- free | premium_monthly | premium_yearly | lifetime
  label text not null,
  tier subscription_tier not null,         -- gating maps to free | premium
  price_cents bigint not null default 0,   -- ZAR cents
  currency text not null default 'ZAR',
  interval text not null default 'none',   -- none | month | year | once
  store_product_id text,                   -- Google Play / Apple SKU
  paystack_plan_code text,                 -- Paystack recurring plan code
  is_active boolean not null default true,
  sort int not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.plans (key, label, tier, price_cents, interval, sort) values
  ('free',            'Free',              'free',        0, 'none',  0),
  ('premium_monthly', 'Premium (Monthly)', 'premium',  3900, 'month', 1),
  ('premium_yearly',  'Premium (Yearly)',  'premium', 39900, 'year',  2),
  ('lifetime',        'Lifetime',          'premium', 99900, 'once',  3)
on conflict (key) do nothing;

alter table public.plans enable row level security;
drop policy if exists "read active plans" on public.plans;
create policy "read active plans" on public.plans
  for select using (is_active or is_super_admin());

-- ============ app_settings: key/value config (some client-readable) ============
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,  -- public rows readable by any signed-in user
  updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value, is_public) values
  ('free_member_limit', '50'::jsonb, true),
  ('features', '{"face_recognition":true,"ai_avatar":true,"data_export":true}'::jsonb, true),
  ('paystack', '{"public_key":"","mode":"test"}'::jsonb, false),
  ('support', '{"email":"fabtechonline@gmail.com","announcement":""}'::jsonb, true),
  ('maintenance', '{"enabled":false,"message":""}'::jsonb, true)
on conflict (key) do nothing;

alter table public.app_settings enable row level security;
drop policy if exists "read public settings" on public.app_settings;
create policy "read public settings" on public.app_settings
  for select using (is_public or is_super_admin());

-- ============ family_billing: per-family subscription state ============
create table if not exists public.family_billing (
  family_id uuid primary key references families(id) on delete cascade,
  plan_key text not null default 'free' references plans(key),
  billing_provider text not null default 'none',  -- none | paystack | google_play | apple | comp | admin
  status text not null default 'none',            -- none | active | non_renewing | grace | expired
  current_period_end timestamptz,                 -- null = lifetime / none
  cancel_at_period_end boolean not null default false,
  is_comp boolean not null default false,         -- admin-granted free access
  paystack_customer_code text,
  paystack_subscription_code text,
  google_purchase_token text,
  google_product_id text,
  apple_original_transaction_id text,
  updated_at timestamptz not null default now()
);

alter table public.family_billing enable row level security;
drop policy if exists "read own billing" on public.family_billing;
create policy "read own billing" on public.family_billing
  for select using (is_super_admin() or has_family_role(family_id, array['admin']::family_role[]));

-- ============ subscription_events: audit + idempotency + payment history ============
create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete set null,
  provider text not null,
  event_type text not null,
  external_id text unique,
  amount_cents bigint,
  currency text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists subscription_events_family_idx on public.subscription_events (family_id, created_at desc);

alter table public.subscription_events enable row level security;
drop policy if exists "read events" on public.subscription_events;
create policy "read events" on public.subscription_events
  for select using (is_super_admin() or has_family_role(family_id, array['admin']::family_role[]));

-- ============ families: suspension + per-family member-limit override ============
alter table public.families add column if not exists is_suspended boolean not null default false;
alter table public.families add column if not exists suspended_reason text;
alter table public.families add column if not exists member_limit int;  -- null = use app default

-- ============ effective tier + recompute ============
create or replace function public.effective_premium(p_family uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from family_billing b join plans p on p.key = b.plan_key
    where b.family_id = p_family and p.tier = 'premium'
      and b.status in ('active', 'non_renewing', 'grace')
      and (b.plan_key = 'lifetime' or b.current_period_end is null or b.current_period_end > now())
  );
$$;

create or replace function public.recompute_family_tier(p_family uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update families
  set subscription_tier = case when effective_premium(p_family)
    then 'premium'::subscription_tier else 'free'::subscription_tier end
  where id = p_family;
end;
$$;

-- ============ member-limit enforcement (free tier) ============
create or replace function public.enforce_member_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tier subscription_tier;
  v_limit int;
  v_count int;
begin
  select subscription_tier into v_tier from families where id = NEW.family_id;
  if v_tier = 'premium' then return NEW; end if;  -- premium = unlimited
  select coalesce(
    (select member_limit from families where id = NEW.family_id),
    (select (value #>> '{}')::int from app_settings where key = 'free_member_limit'),
    50
  ) into v_limit;
  select count(*) into v_count from members where family_id = NEW.family_id;
  if v_count >= v_limit then
    raise exception 'member_limit_reached' using errcode = 'check_violation';
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_member_limit on public.members;
create trigger trg_member_limit before insert on public.members
  for each row execute function public.enforce_member_limit();

-- ============ super-admin RPCs ============
create or replace function public.admin_update_plan(
  p_key text, p_label text, p_price_cents bigint, p_interval text,
  p_is_active boolean, p_paystack_plan_code text, p_store_product_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  update plans set
    label = coalesce(p_label, label),
    price_cents = coalesce(p_price_cents, price_cents),
    interval = coalesce(p_interval, interval),
    is_active = coalesce(p_is_active, is_active),
    paystack_plan_code = p_paystack_plan_code,
    store_product_id = p_store_product_id,
    updated_at = now()
  where key = p_key;
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'update_plan', p_key, jsonb_build_object('price_cents', p_price_cents, 'active', p_is_active));
end;
$$;

create or replace function public.admin_set_family_plan(
  p_family uuid, p_plan_key text, p_expires_at timestamptz, p_comp boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  insert into family_billing (family_id, plan_key, billing_provider, status, current_period_end, is_comp)
  values (
    p_family, p_plan_key,
    case when p_comp then 'comp' else 'admin' end,
    case when p_plan_key = 'free' then 'none' else 'active' end,
    case when p_plan_key = 'lifetime' then null else p_expires_at end,
    coalesce(p_comp, false))
  on conflict (family_id) do update set
    plan_key = excluded.plan_key,
    billing_provider = excluded.billing_provider,
    status = excluded.status,
    current_period_end = excluded.current_period_end,
    is_comp = excluded.is_comp,
    cancel_at_period_end = false,
    updated_at = now();
  perform recompute_family_tier(p_family);
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'set_family_plan', p_family::text,
          jsonb_build_object('plan', p_plan_key, 'comp', p_comp, 'expires_at', p_expires_at));
end;
$$;

create or replace function public.admin_suspend_family(p_family uuid, p_reason text, p_suspend boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  update families set
    is_suspended = coalesce(p_suspend, true),
    suspended_reason = case when coalesce(p_suspend, true) then p_reason else null end
  where id = p_family;
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), case when coalesce(p_suspend, true) then 'suspend_family' else 'unsuspend_family' end,
          p_family::text, jsonb_build_object('reason', p_reason));
end;
$$;

create or replace function public.admin_set_member_limit(p_family uuid, p_limit int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  update families set member_limit = p_limit where id = p_family;
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'set_member_limit', p_family::text, jsonb_build_object('limit', p_limit));
end;
$$;

create or replace function public.admin_get_settings()
returns setof app_settings language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  return query select * from app_settings order by key;
end;
$$;

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  insert into app_settings (key, value, updated_at) values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'set_setting', p_key, p_value);
end;
$$;

-- richer platform analytics (super-admin only)
create or replace function public.admin_analytics()
returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  select jsonb_build_object(
    'total_users', (select count(*) from profiles),
    'blocked_users', (select count(*) from profiles where status = 'blocked'),
    'total_families', (select count(*) from families),
    'suspended_families', (select count(*) from families where is_suspended),
    'premium_families', (select count(*) from families where subscription_tier = 'premium'),
    'free_families', (select count(*) from families where subscription_tier = 'free'),
    'lifetime_families', (select count(*) from family_billing where plan_key = 'lifetime' and status = 'active'),
    'comp_families', (select count(*) from family_billing where is_comp and status <> 'none'),
    'new_families_30d', (select count(*) from families where created_at > now() - interval '30 days'),
    'total_members', (select count(*) from members),
    'mrr_cents', (
      select coalesce(sum(case p.interval
        when 'month' then p.price_cents
        when 'year' then p.price_cents / 12 else 0 end), 0)
      from family_billing b join plans p on p.key = b.plan_key
      where b.status in ('active', 'non_renewing') and not b.is_comp
    ),
    'plan_distribution', (
      select coalesce(jsonb_object_agg(plan_key, c), '{}'::jsonb)
      from (select plan_key, count(*) c from family_billing group by plan_key) t
    )
  ) into result;
  return result;
end;
$$;

-- per-family detail: billing + counts + recent payment events
create or replace function public.admin_family_detail(p_family uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  select jsonb_build_object(
    'family', (select to_jsonb(f) from families f where f.id = p_family),
    'billing', (select to_jsonb(b) from family_billing b where b.family_id = p_family),
    'member_count', (select count(*) from members where family_id = p_family),
    'user_count', (select count(*) from family_members where family_id = p_family),
    'events', (select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc), '[]'::jsonb)
               from (select * from subscription_events where family_id = p_family order by created_at desc limit 25) e)
  ) into result;
  return result;
end;
$$;

-- extend the families listing with suspension + plan + period end
drop function if exists public.admin_list_families();
create or replace function public.admin_list_families()
returns table (
  id uuid, name text, subscription_tier subscription_tier,
  member_count bigint, person_count bigint, created_at timestamptz,
  is_suspended boolean, plan_key text, current_period_end timestamptz, is_comp boolean
) language plpgsql security definer set search_path = public as $$
begin
  if not is_super_admin() then raise exception 'Not authorized'; end if;
  return query
    select f.id, f.name, f.subscription_tier,
      (select count(*) from family_members fm where fm.family_id = f.id),
      (select count(*) from members m where m.family_id = f.id),
      f.created_at, f.is_suspended,
      coalesce(b.plan_key, 'free'), b.current_period_end, coalesce(b.is_comp, false)
    from families f
    left join family_billing b on b.family_id = f.id
    order by f.created_at desc;
end;
$$;

-- backfill a billing row for every existing family (premium ones become admin-comped)
insert into public.family_billing (family_id, plan_key, billing_provider, status, is_comp)
select f.id,
  case when f.subscription_tier = 'premium' then 'premium_monthly' else 'free' end,
  case when f.subscription_tier = 'premium' then 'admin' else 'none' end,
  case when f.subscription_tier = 'premium' then 'active' else 'none' end,
  f.subscription_tier = 'premium'
from families f
on conflict (family_id) do nothing;
