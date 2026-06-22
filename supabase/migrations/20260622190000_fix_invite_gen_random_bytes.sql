-- ============================================================================
-- Fix: create_invitation failed with "function gen_random_bytes(integer) does
-- not exist" (SQLSTATE 42883).
--
-- gen_random_bytes() is provided by the pgcrypto extension, which on Supabase
-- is installed in the `extensions` schema. The function was defined with
-- `set search_path = public`, so the unqualified call could not be resolved.
-- Recreate it with `extensions` on the search_path.
-- ============================================================================

create or replace function public.create_invitation(
  p_family uuid,
  p_role family_role default 'contributor',
  p_expires_in interval default interval '30 days',
  p_target_member uuid default null
)
returns invitations
language plpgsql
security definer
set search_path = public, extensions
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
  insert into invitations (family_id, code, role, expires_at, created_by, target_member_id)
  values (p_family, v_code, p_role, now() + p_expires_in, v_uid, p_target_member)
  returning * into v_inv;
  return v_inv;
end;
$$;
