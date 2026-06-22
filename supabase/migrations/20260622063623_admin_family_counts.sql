-- ============================================================================
-- Clarify admin family counts: distinguish app users (seats) from tree people.
-- ----------------------------------------------------------------------------
-- The previous member_count only counted family_members (login users). Add
-- person_count (people in the tree) so the console shows both. Counts are
-- aggregate billing metadata, not tree content.
-- ============================================================================

-- Return signature changes (new column), so drop the old function first.
drop function if exists public.admin_list_families();

create or replace function public.admin_list_families()
returns table (
  id uuid,
  name text,
  subscription_tier subscription_tier,
  member_count bigint,
  person_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin() then
    raise exception 'Not authorized';
  end if;
  return query
    select f.id,
           f.name,
           f.subscription_tier,
           (select count(*) from family_members fm where fm.family_id = f.id),
           (select count(*) from members m where m.family_id = f.id),
           f.created_at
    from families f
    order by f.created_at desc;
end;
$$;
