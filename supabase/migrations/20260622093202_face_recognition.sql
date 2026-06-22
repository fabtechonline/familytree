-- ============================================================================
-- Point & Recognize: on-device face embeddings + pgvector matching.
-- ----------------------------------------------------------------------------
-- Embeddings are computed ON DEVICE (MobileFaceNet) and only stored/matched
-- within a single family. Strictly opt-in: family.settings->>'face_recognition'
-- must be 'true'. Raw photos never leave the phone for matching.
-- ============================================================================

create extension if not exists vector;

create table face_embeddings (
  id         uuid primary key default gen_random_uuid(),
  member_id  uuid not null unique references members (id) on delete cascade,
  family_id  uuid not null references families (id) on delete cascade,
  embedding  vector(192) not null,
  created_at timestamptz not null default now()
);
create index face_embeddings_family_idx on face_embeddings (family_id);

alter table face_embeddings enable row level security;

create policy "family reads embeddings"
  on face_embeddings for select using (is_member_of(family_id));

create policy "editors manage embeddings"
  on face_embeddings for all
  using (has_family_role(family_id, array['admin','editor']::family_role[]))
  with check (has_family_role(family_id, array['admin','editor']::family_role[]));

-- Opt-in toggle stored on families.settings (admin only).
create or replace function public.set_face_recognition(p_family uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_family_role(p_family, array['admin']::family_role[]) then
    raise exception 'Only admins can change this setting';
  end if;
  update families
  set settings = coalesce(settings, '{}'::jsonb)
                 || jsonb_build_object('face_recognition', p_enabled)
  where id = p_family;
  -- Revoking consent removes stored embeddings.
  if not p_enabled then
    delete from face_embeddings where family_id = p_family;
  end if;
end;
$$;

create or replace function public._face_enabled(p_family uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select settings->>'face_recognition' from families where id = p_family), 'false') = 'true';
$$;

-- Store/replace a member's embedding (editor; consent required).
create or replace function public.upsert_face_embedding(
  p_member uuid, p_family uuid, p_embedding text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_family_role(p_family, array['admin','editor']::family_role[]) then
    raise exception 'Not authorized';
  end if;
  if not _face_enabled(p_family) then
    raise exception 'Face recognition is not enabled for this family';
  end if;
  insert into face_embeddings (member_id, family_id, embedding)
  values (p_member, p_family, p_embedding::vector)
  on conflict (member_id)
  do update set embedding = excluded.embedding, created_at = now();
end;
$$;

-- Nearest member to a probe embedding within the family (L2 distance).
create or replace function public.match_face(
  p_family uuid, p_embedding text, p_max_distance float default 1.0)
returns table (member_id uuid, distance float)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_member_of(p_family) then
    raise exception 'Not a member of this family';
  end if;
  if not _face_enabled(p_family) then
    raise exception 'Face recognition is not enabled for this family';
  end if;
  return query
    select fe.member_id, (fe.embedding <-> p_embedding::vector) as distance
    from face_embeddings fe
    where fe.family_id = p_family
    order by fe.embedding <-> p_embedding::vector
    limit 1;
end;
$$;
