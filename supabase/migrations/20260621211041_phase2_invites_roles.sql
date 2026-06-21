-- ============================================================================
-- Phase 2: invitations & roster RPCs
-- ----------------------------------------------------------------------------
-- SECURITY DEFINER functions so a not-yet-member can preview/join via a code
-- (RLS would otherwise block reading the invite / self-inserting membership),
-- and so family members can read each other's basic profile for the roster
-- (profiles RLS only exposes a user's own row).
-- ============================================================================

-- Create an invite with a unique short code (admin only).
create or replace function public.create_invitation(
  p_family uuid,
  p_role family_role default 'contributor',
  p_expires_in interval default interval '30 days'
)
returns invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_code text;
  v_inv  invitations;
begin
  if not has_family_role(p_family, array['admin']::family_role[]) then
    raise exception 'Only admins can create invitations';
  end if;

  loop
    v_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
    exit when not exists (select 1 from invitations where code = v_code);
  end loop;

  insert into invitations (family_id, code, role, expires_at, created_by)
  values (p_family, v_code, p_role, now() + p_expires_in, v_uid)
  returning * into v_inv;
  return v_inv;
end;
$$;

-- Preview an invite (family name + role) without joining.
create or replace function public.invite_preview(p_code text)
returns table (
  family_id uuid,
  family_name text,
  role family_role,
  valid boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select i.family_id,
         f.name,
         i.role,
         (i.expires_at is null or i.expires_at > now()) as valid
  from invitations i
  join families f on f.id = i.family_id
  where i.code = upper(trim(p_code));
end;
$$;

-- Join a family using an invite code. Idempotent: re-joining is a no-op.
create or replace function public.join_family_with_code(p_code text)
returns families
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_inv    invitations;
  v_family families;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_inv from invitations where code = upper(trim(p_code));
  if v_inv.id is null then
    raise exception 'Invalid invite code';
  end if;
  if v_inv.expires_at is not null and v_inv.expires_at < now() then
    raise exception 'This invite has expired';
  end if;

  insert into family_members (family_id, user_id, role, invited_by)
  values (v_inv.family_id, v_uid, v_inv.role, v_inv.created_by)
  on conflict (family_id, user_id) do nothing;

  select * into v_family from families where id = v_inv.family_id;
  return v_family;
end;
$$;

-- Roster of a family with member display info (members only).
create or replace function public.family_roster(p_family uuid)
returns table (
  user_id uuid,
  role family_role,
  display_name text,
  email text,
  joined_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_member_of(p_family) then
    raise exception 'Not a member of this family';
  end if;

  return query
  select fm.user_id, fm.role, p.display_name, p.email, fm.joined_at
  from family_members fm
  join profiles p on p.id = fm.user_id
  where fm.family_id = p_family
  order by fm.joined_at;
end;
$$;
