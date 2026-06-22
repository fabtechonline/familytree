-- ============================================================================
-- Member memories: photos (with captions) attached to a person.
-- ============================================================================

create table member_media (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families (id) on delete cascade,
  member_id   uuid not null references members (id) on delete cascade,
  uploaded_by uuid references profiles (id),
  media_url   text not null,
  caption     text,
  created_at  timestamptz not null default now()
);
create index member_media_member_idx on member_media (member_id, created_at);

alter table member_media enable row level security;

create policy "family reads memories"
  on member_media for select using (is_member_of(family_id));

create policy "editors add memories"
  on member_media for insert
  with check (has_family_role(family_id, array['admin','editor']::family_role[]));

create policy "authors or admins delete memories"
  on member_media for delete
  using (
    uploaded_by = auth.uid()
    or has_family_role(family_id, array['admin']::family_role[])
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'member_media'
  ) then
    alter publication supabase_realtime add table public.member_media;
  end if;
end;
$$;
