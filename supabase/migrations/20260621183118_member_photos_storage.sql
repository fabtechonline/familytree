-- ============================================================================
-- Storage: member-photos bucket
-- ----------------------------------------------------------------------------
-- Public-read bucket for member avatars/photos (so the app can render them via
-- plain public URLs in the tree and lists). Writes are restricted to family
-- editors/admins by RLS, keyed on the first path segment which is the family id:
--   path convention:  {family_id}/{member_id}/{filename}
--
-- Tradeoff: public read means anyone with the (unguessable, UUID-based) URL can
-- view a photo. A later phase can switch to a private bucket + signed URLs if
-- stricter privacy is required.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', true)
on conflict (id) do nothing;

-- Helper: the family id encoded as the first folder of the object path.
-- (storage.foldername returns the path segments as a text[].)

create policy "member photos: family editors can upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'member-photos'
    and has_family_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin','editor']::family_role[]
    )
  );

create policy "member photos: family editors can update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'member-photos'
    and has_family_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin','editor']::family_role[]
    )
  );

create policy "member photos: family editors can delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'member-photos'
    and has_family_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin','editor']::family_role[]
    )
  );
