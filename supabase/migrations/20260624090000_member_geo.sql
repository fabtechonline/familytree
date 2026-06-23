-- Geocoded coordinates for the Family Map. Derived from `address` (home) and
-- `birth_place` (birthplace) via Nominatim, cached here so each is geocoded once.
-- Nullable + additive; row-level RLS already covers the new columns.

alter table public.members
  add column if not exists home_lat double precision,
  add column if not exists home_lng double precision,
  add column if not exists birth_lat double precision,
  add column if not exists birth_lng double precision;
