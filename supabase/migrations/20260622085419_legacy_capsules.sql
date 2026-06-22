-- ============================================================================
-- Legacy capsules: messages sealed until a future unlock date.
-- ----------------------------------------------------------------------------
-- The body must stay hidden until unlock_at — even from direct queries. So the
-- table grants NO direct SELECT; reads go through list_capsules(), a SECURITY
-- DEFINER function that only returns the body once unlocked.
-- ============================================================================

create table legacy_capsules (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references families (id) on delete cascade,
  author_id  uuid not null references profiles (id),
  title      text not null,
  body       text,
  unlock_at  timestamptz not null,
  created_at timestamptz not null default now()
);
create index legacy_capsules_family_idx on legacy_capsules (family_id, unlock_at);

alter table legacy_capsules enable row level security;

-- Members can create capsules; no direct SELECT policy (reads via RPC only).
create policy "members create capsules"
  on legacy_capsules for insert
  with check (
    author_id = auth.uid()
    and has_family_role(family_id,
        array['admin','editor','contributor']::family_role[])
  );

create policy "authors or admins delete capsules"
  on legacy_capsules for delete
  using (
    author_id = auth.uid()
    or has_family_role(family_id, array['admin']::family_role[])
  );

-- Read capsules: body only revealed once unlocked.
create or replace function public.list_capsules(p_family uuid)
returns table (
  id uuid,
  title text,
  body text,
  unlock_at timestamptz,
  author_id uuid,
  created_at timestamptz,
  locked boolean
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
    select c.id,
           c.title,
           case when c.unlock_at <= now() then c.body else null end,
           c.unlock_at,
           c.author_id,
           c.created_at,
           (c.unlock_at > now()) as locked
    from legacy_capsules c
    where c.family_id = p_family
    order by c.unlock_at;
end;
$$;
