-- ============================================================================
-- Family RPCs & triggers
-- ----------------------------------------------------------------------------
-- create_family resolves an RLS chicken-and-egg: the family_members "admins
-- manage roster" policy requires already being an admin, so a brand-new creator
-- could not insert their own admin row. This SECURITY DEFINER function creates
-- the family AND the creator's admin membership atomically.
-- ============================================================================

create or replace function public.create_family(p_name text)
returns families
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_family families;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Family name is required';
  end if;

  insert into families (name, created_by)
  values (trim(p_name), v_uid)
  returning * into v_family;

  insert into family_members (family_id, user_id, role, invited_by)
  values (v_family.id, v_uid, 'admin', v_uid);

  return v_family;
end;
$$;

-- Keep members.updated_at fresh on every update.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger members_touch_updated_at
  before update on members
  for each row execute function public.touch_updated_at();
