-- Enforce family suspension at the database layer (RLS), not just the UI.
-- Strategy: keep the family ROW + the user's OWN membership readable (so the app
-- can still show the "suspended" notice), but make the membership helpers
-- exclude suspended families — which blocks every family CONTENT table
-- (members, relationships, feed, capsules, media, suggestions, invitations,
-- face embeddings, billing) that gates on is_member_of / has_family_role.

-- 1. A user may always read their OWN membership rows (even for a suspended
--    family) — this is what lets the family list load and trigger the notice.
drop policy if exists "read own membership" on public.family_members;
create policy "read own membership" on public.family_members
  for select using (user_id = auth.uid());

-- 2. The family row stays visible to its members regardless of suspension
--    (decoupled from is_member_of, which is about to exclude suspended).
drop policy if exists "members read their families" on public.families;
create policy "members read their families" on public.families
  for select using (
    exists (select 1 from family_members m where m.family_id = families.id and m.user_id = auth.uid())
    or is_super_admin()
  );

-- 3. Membership helpers now exclude suspended families → all content gated on
--    them is blocked when a family is suspended.
create or replace function public.is_member_of(p_family uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from family_members fm join families f on f.id = fm.family_id
    where fm.family_id = p_family and fm.user_id = auth.uid() and not f.is_suspended
  );
$$;

create or replace function public.has_family_role(p_family uuid, p_roles family_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from family_members fm join families f on f.id = fm.family_id
    where fm.family_id = p_family and fm.user_id = auth.uid()
      and fm.role = any(p_roles) and not f.is_suspended
  );
$$;
