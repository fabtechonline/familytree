-- Track who created/updated a member. created_by + created_at + updated_at
-- already exist; add updated_by, auto-stamp it on every update, and expose a
-- name-resolving RPC for the profile page (gated to family members).

alter table public.members add column if not exists updated_by uuid references profiles(id);

create or replace function public.set_member_updated_by()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists trg_members_updated_by on public.members;
create trigger trg_members_updated_by before update on public.members
  for each row execute function set_member_updated_by();

-- Resolve creator/updater display names (or email) for a member the caller can see.
create or replace function public.member_audit(p_member uuid)
returns table (created_by_name text, created_at timestamptz, updated_by_name text, updated_at timestamptz)
language sql security definer set search_path = public stable as $$
  select
    coalesce(cp.display_name, cu.email, 'Unknown'),
    m.created_at,
    coalesce(up.display_name, uu.email),
    m.updated_at
  from members m
  left join profiles cp on cp.id = m.created_by
  left join auth.users cu on cu.id = m.created_by
  left join profiles up on up.id = m.updated_by
  left join auth.users uu on uu.id = m.updated_by
  where m.id = p_member and is_member_of(m.family_id);
$$;
