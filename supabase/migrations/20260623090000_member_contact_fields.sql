-- Add phone, address, and occupation to members. Nullable + additive, so it is
-- backward compatible with existing clients. RLS is row-level (not column-level)
-- so existing members policies already cover the new columns.

alter table public.members
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists occupation text;

-- apply_suggestion enumerates columns explicitly, so extend it to carry the new
-- fields when a contributor's add/edit suggestion is approved.
create or replace function public.apply_suggestion(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  s edit_suggestions;
  p jsonb;
begin
  select * into s from edit_suggestions where id = p_id;
  if s.id is null then
    raise exception 'Suggestion not found';
  end if;
  if not has_family_role(s.family_id, array['admin']::family_role[]) then
    raise exception 'Only admins can approve suggestions';
  end if;
  if s.status <> 'pending' then
    raise exception 'Suggestion already reviewed';
  end if;
  p := s.payload;

  if s.kind = 'add_member' then
    insert into members (family_id, first_name, last_name, maiden_name, gender,
                         birth_date, death_date, is_living, birth_place, bio,
                         phone, address, occupation,
                         created_by)
    values (
      s.family_id,
      p->>'first_name',
      p->>'last_name',
      p->>'maiden_name',
      p->>'gender',
      nullif(p->>'birth_date','')::date,
      nullif(p->>'death_date','')::date,
      coalesce((p->>'is_living')::boolean, true),
      p->>'birth_place',
      p->>'bio',
      p->>'phone',
      p->>'address',
      p->>'occupation',
      s.suggested_by
    );
  elsif s.kind = 'edit_member' then
    update members set
      first_name  = p->>'first_name',
      last_name   = p->>'last_name',
      maiden_name = p->>'maiden_name',
      gender      = p->>'gender',
      birth_date  = nullif(p->>'birth_date','')::date,
      death_date  = nullif(p->>'death_date','')::date,
      is_living   = coalesce((p->>'is_living')::boolean, true),
      birth_place = p->>'birth_place',
      bio         = p->>'bio',
      phone       = p->>'phone',
      address     = p->>'address',
      occupation  = p->>'occupation'
    where id = s.target_member_id;
  else
    raise exception 'Unknown suggestion kind: %', s.kind;
  end if;

  update edit_suggestions
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_id;
end;
$$;
