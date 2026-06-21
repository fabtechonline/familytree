-- ============================================================================
-- Phase 2: contributor edit-suggestion queue
-- ----------------------------------------------------------------------------
-- Contributors can't write members directly (RLS). Instead they submit
-- suggestions which admins approve (applied) or reject. apply_suggestion is
-- SECURITY DEFINER so it can perform the member write on the admin's behalf.
-- ============================================================================

create type suggestion_status as enum ('pending', 'approved', 'rejected');

create table edit_suggestions (
  id               uuid primary key default gen_random_uuid(),
  family_id        uuid not null references families (id) on delete cascade,
  suggested_by     uuid not null references profiles (id),
  kind             text not null,            -- 'add_member' | 'edit_member'
  target_member_id uuid references members (id) on delete cascade,
  payload          jsonb not null default '{}'::jsonb,
  note             text,
  status           suggestion_status not null default 'pending',
  reviewed_by      uuid references profiles (id),
  reviewed_at      timestamptz,
  created_at       timestamptz not null default now()
);
create index edit_suggestions_family_idx on edit_suggestions (family_id, status);

alter table edit_suggestions enable row level security;

-- Contributors and above may submit suggestions for their family.
create policy "members suggest edits"
  on edit_suggestions for insert
  with check (
    suggested_by = auth.uid()
    and has_family_role(family_id,
        array['admin','editor','contributor']::family_role[])
  );

-- The suggester sees their own; admins see all in the family.
create policy "read own or admin suggestions"
  on edit_suggestions for select
  using (
    suggested_by = auth.uid()
    or has_family_role(family_id, array['admin']::family_role[])
  );

-- Admins can update (e.g. reject) suggestions.
create policy "admins update suggestions"
  on edit_suggestions for update
  using (has_family_role(family_id, array['admin']::family_role[]))
  with check (has_family_role(family_id, array['admin']::family_role[]));

-- Apply a pending suggestion (admin only): performs the member write and marks
-- the suggestion approved.
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
      bio         = p->>'bio'
    where id = s.target_member_id;
  else
    raise exception 'Unknown suggestion kind: %', s.kind;
  end if;

  update edit_suggestions
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_id;
end;
$$;

-- Stream suggestions so the admin's queue updates live.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'edit_suggestions'
  ) then
    alter publication supabase_realtime add table public.edit_suggestions;
  end if;
end;
$$;
