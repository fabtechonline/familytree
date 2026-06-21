-- ============================================================================
-- Enable Realtime (postgres changes) on the collaborative tables.
-- ----------------------------------------------------------------------------
-- Adds tables to the `supabase_realtime` publication so the app can subscribe
-- to inserts/updates/deletes. RLS still applies: a subscriber only receives
-- changes for rows they can SELECT, so family isolation is preserved.
-- ============================================================================

do $$
declare
  t text;
  tables text[] := array['members', 'relationships', 'family_members', 'announcements'];
begin
  foreach t in array tables loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
