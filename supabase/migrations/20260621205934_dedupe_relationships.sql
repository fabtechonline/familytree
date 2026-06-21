-- ============================================================================
-- Deduplicate relationships and prevent future duplicates.
-- ----------------------------------------------------------------------------
-- Bug: adding a sibling copied the sibling's parents onto a member that already
-- had those parents, producing duplicate parent edges. Remove existing exact
-- duplicates (same family/from/to/type), then enforce uniqueness so inserts
-- can't create them again.
-- ============================================================================

delete from relationships a
using relationships b
where a.id > b.id
  and a.family_id = b.family_id
  and a.from_member = b.from_member
  and a.to_member = b.to_member
  and a.type = b.type;

create unique index if not exists relationships_unique_edge
  on relationships (family_id, from_member, to_member, type);
