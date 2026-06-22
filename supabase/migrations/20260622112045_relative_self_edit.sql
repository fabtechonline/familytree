-- ============================================================================
-- Relative role: invite-to-claim linking + self-edit of own profile.
-- ============================================================================

-- Invites can target a specific member to "claim".
alter table invitations
  add column if not exists target_member_id uuid references members (id) on delete set null;

-- Relatives may update ONLY the member linked to them.
create policy "relatives edit own member"
  on members for update
  using (linked_user_id = auth.uid()
         and has_family_role(family_id, array['relative']::family_role[]))
  with check (linked_user_id = auth.uid()
         and has_family_role(family_id, array['relative']::family_role[]));

-- create_invitation gains an optional target member.
drop function if exists public.create_invitation(uuid, family_role, interval);
create or replace function public.create_invitation(
  p_family uuid,
  p_role family_role default 'contributor',
  p_expires_in interval default interval '30 days',
  p_target_member uuid default null
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
  insert into invitations (family_id, code, role, expires_at, created_by, target_member_id)
  values (p_family, v_code, p_role, now() + p_expires_in, v_uid, p_target_member)
  returning * into v_inv;
  return v_inv;
end;
$$;

-- invite_preview also reports the claimed member's name (if any).
drop function if exists public.invite_preview(text);
create or replace function public.invite_preview(p_code text)
returns table (
  family_id uuid,
  family_name text,
  role family_role,
  valid boolean,
  target_member_id uuid,
  target_member_name text
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
         (i.expires_at is null or i.expires_at > now()) as valid,
         i.target_member_id,
         nullif(trim(coalesce(m.first_name, '') || ' ' || coalesce(m.last_name, '')), '')
  from invitations i
  join families f on f.id = i.family_id
  left join members m on m.id = i.target_member_id
  where i.code = upper(trim(p_code));
end;
$$;

-- Joining with a targeted invite links the member's profile to the new user.
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

  -- Link the claimed profile to this user (only if not already linked).
  if v_inv.target_member_id is not null then
    update members
    set linked_user_id = v_uid
    where id = v_inv.target_member_id and linked_user_id is null;
  end if;

  select * into v_family from families where id = v_inv.family_id;
  return v_family;
end;
$$;
