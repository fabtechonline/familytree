-- ============================================================================
-- Allow authors (or family admins) to delete their announcements.
-- ============================================================================

create policy "authors or admins delete announcements"
  on announcements for delete
  using (
    author_id = auth.uid()
    or has_family_role(family_id, array['admin']::family_role[])
  );
