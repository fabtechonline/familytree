-- ============================================================================
-- FamilyTree — initial schema
-- ----------------------------------------------------------------------------
-- Multi-tenant SaaS where the tenant is a `family`. Family content (members,
-- relationships, announcements, media, face embeddings) is isolated per family
-- via Row Level Security. The platform "super admin" can manage ACCOUNTS only
-- (profiles/billing/auth) and is deliberately given NO RLS access to any
-- family-content table — see the note before that section.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
create type account_status as enum ('active', 'blocked', 'suspended');
create type family_role     as enum ('admin', 'editor', 'contributor', 'viewer');
create type subscription_tier as enum ('free', 'premium');
create type rel_type        as enum ('parent', 'spouse', 'partner');
create type rel_subtype     as enum ('biological', 'adoptive', 'step', 'foster');

-- ----------------------------------------------------------------------------
-- profiles: one row per auth user (account-level data, NOT family data)
-- ----------------------------------------------------------------------------
create table profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  email          text,
  display_name   text,
  avatar_url     text,
  status         account_status not null default 'active',
  is_super_admin boolean not null default false,
  created_at     timestamptz not null default now(),
  last_active_at timestamptz
);

-- Auto-create a profile when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- families: the SaaS tenant
-- ----------------------------------------------------------------------------
create table families (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  created_by        uuid not null references profiles (id),
  subscription_tier subscription_tier not null default 'free',
  settings          jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- family_members: which users belong to which family, and their role
-- ----------------------------------------------------------------------------
create table family_members (
  family_id  uuid not null references families (id) on delete cascade,
  user_id    uuid not null references profiles (id) on delete cascade,
  role       family_role not null default 'viewer',
  invited_by uuid references profiles (id),
  joined_at  timestamptz not null default now(),
  primary key (family_id, user_id)
);
create index family_members_user_idx on family_members (user_id);

-- ----------------------------------------------------------------------------
-- Membership helper functions (SECURITY DEFINER to avoid RLS recursion)
-- ----------------------------------------------------------------------------
create or replace function public.is_member_of(p_family uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from family_members
    where family_id = p_family and user_id = auth.uid()
  );
$$;

create or replace function public.has_family_role(p_family uuid, p_roles family_role[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from family_members
    where family_id = p_family
      and user_id = auth.uid()
      and role = any(p_roles)
  );
$$;

-- SECURITY DEFINER so a policy ON profiles can call it without recursing into
-- the very RLS policies being evaluated.
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_super_admin = true
  );
$$;

-- ----------------------------------------------------------------------------
-- members: every person in the tree (may or may not be an app user)
-- ----------------------------------------------------------------------------
create table members (
  id             uuid primary key default gen_random_uuid(),
  family_id      uuid not null references families (id) on delete cascade,
  first_name     text not null,
  last_name      text,
  maiden_name    text,
  gender         text,
  birth_date     date,
  death_date     date,
  is_living      boolean not null default true,
  birth_place    text,
  bio            text,
  photo_url      text,
  avatar_config  jsonb,
  linked_user_id uuid references profiles (id),
  created_by     uuid references profiles (id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index members_family_idx on members (family_id);

-- ----------------------------------------------------------------------------
-- relationships: explicit graph edges (parent->child, spouse/partner)
-- ----------------------------------------------------------------------------
create table relationships (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families (id) on delete cascade,
  from_member uuid not null references members (id) on delete cascade,
  to_member   uuid not null references members (id) on delete cascade,
  type        rel_type not null,
  subtype     rel_subtype not null default 'biological',
  start_date  date,
  end_date    date,
  created_at  timestamptz not null default now(),
  check (from_member <> to_member)
);
create index relationships_family_idx on relationships (family_id);
create index relationships_from_idx on relationships (from_member);
create index relationships_to_idx on relationships (to_member);

-- ----------------------------------------------------------------------------
-- invitations: universal family login (link / QR based)
-- ----------------------------------------------------------------------------
create table invitations (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references families (id) on delete cascade,
  code       text not null unique,
  role       family_role not null default 'contributor',
  expires_at timestamptz,
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- announcements: private family feed
-- ----------------------------------------------------------------------------
create table announcements (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references families (id) on delete cascade,
  author_id  uuid not null references profiles (id),
  type       text not null default 'news',
  title      text not null,
  body       text,
  media_url  text,
  created_at timestamptz not null default now()
);
create index announcements_family_idx on announcements (family_id);

-- ----------------------------------------------------------------------------
-- audit_log: super-admin & sensitive actions (append-only)
-- ----------------------------------------------------------------------------
create table audit_log (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid references profiles (id),
  action     text not null,
  target_id  text,
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table profiles       enable row level security;
alter table families       enable row level security;
alter table family_members enable row level security;
alter table members        enable row level security;
alter table relationships  enable row level security;
alter table invitations    enable row level security;
alter table announcements  enable row level security;
alter table audit_log      enable row level security;

-- ---- profiles --------------------------------------------------------------
-- A user sees and edits only their own profile. Super admins (account console)
-- may read all profiles — accounts only, never family content.
create policy "own profile readable"
  on profiles for select using (id = auth.uid());

create policy "own profile updatable"
  on profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy "super admin reads all profiles"
  on profiles for select using (is_super_admin());

-- ---- families --------------------------------------------------------------
create policy "members read their families"
  on families for select using (is_member_of(id));

create policy "authenticated can create a family"
  on families for insert with check (created_by = auth.uid());

create policy "admins update their family"
  on families for update
  using (has_family_role(id, array['admin']::family_role[]));

-- ---- family_members --------------------------------------------------------
create policy "members read their family roster"
  on family_members for select using (is_member_of(family_id));

create policy "admins manage roster"
  on family_members for all
  using (has_family_role(family_id, array['admin']::family_role[]))
  with check (has_family_role(family_id, array['admin']::family_role[]));

-- ---- members (people in the tree) ------------------------------------------
-- NOTE: no super-admin policy here by design — the platform owner cannot read
-- family tree content. Same for relationships / announcements below.
create policy "family can read members"
  on members for select using (is_member_of(family_id));

create policy "editors write members"
  on members for all
  using (has_family_role(family_id, array['admin','editor']::family_role[]))
  with check (has_family_role(family_id, array['admin','editor']::family_role[]));

-- ---- relationships ---------------------------------------------------------
create policy "family can read relationships"
  on relationships for select using (is_member_of(family_id));

create policy "editors write relationships"
  on relationships for all
  using (has_family_role(family_id, array['admin','editor']::family_role[]))
  with check (has_family_role(family_id, array['admin','editor']::family_role[]));

-- ---- invitations -----------------------------------------------------------
create policy "admins read invitations"
  on invitations for select
  using (has_family_role(family_id, array['admin']::family_role[]));

create policy "admins create invitations"
  on invitations for insert
  with check (has_family_role(family_id, array['admin']::family_role[]));

-- ---- announcements ---------------------------------------------------------
create policy "family reads announcements"
  on announcements for select using (is_member_of(family_id));

create policy "members post announcements"
  on announcements for insert
  with check (
    author_id = auth.uid()
    and has_family_role(family_id, array['admin','editor','contributor']::family_role[])
  );

-- ---- audit_log -------------------------------------------------------------
-- Readable only by super admins; writes happen server-side (service role).
create policy "super admin reads audit log"
  on audit_log for select using (is_super_admin());
