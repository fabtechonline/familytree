-- ============================================================================
-- Super-admin (platform owner) RPCs.
-- ----------------------------------------------------------------------------
-- All functions verify is_super_admin() and operate ONLY on account/billing
-- data: profiles (accounts), families (name/tier/member-count for billing),
-- and the audit log. They deliberately never expose family-tree CONTENT
-- (members, relationships, announcements, media, face embeddings).
-- ============================================================================

create or replace function public.admin_platform_stats()
returns table (
  total_users bigint,
  total_families bigint,
  premium_families bigint,
  blocked_users bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;
  return query
    select
      (select count(*) from profiles),
      (select count(*) from families),
      (select count(*) from families where subscription_tier = 'premium'),
      (select count(*) from profiles where status = 'blocked');
end;
$$;

-- Families with billing-relevant info only (no tree content).
create or replace function public.admin_list_families()
returns table (
  id uuid,
  name text,
  subscription_tier subscription_tier,
  member_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;
  return query
    select f.id,
           f.name,
           f.subscription_tier,
           (select count(*) from family_members fm where fm.family_id = f.id),
           f.created_at
    from families f
    order by f.created_at desc;
end;
$$;

create or replace function public.admin_set_account_status(
  p_user uuid,
  p_status account_status
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;
  update profiles set status = p_status where id = p_user;
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'set_account_status', p_user::text,
          jsonb_build_object('status', p_status));
end;
$$;

create or replace function public.admin_set_subscription(
  p_family uuid,
  p_tier subscription_tier
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;
  update families set subscription_tier = p_tier where id = p_family;
  insert into audit_log (actor_id, action, target_id, metadata)
  values (auth.uid(), 'set_subscription', p_family::text,
          jsonb_build_object('tier', p_tier));
end;
$$;
