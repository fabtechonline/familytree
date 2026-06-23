# Riza Supabase Backend Contract

The web app (React) and the Flutter mobile app share **one** Supabase backend —
same project URL, publishable key, tables, RPCs, RLS, storage, and realtime.
**Do not change the schema.** Code the web client against this contract.

Auth is client-side with the publishable key; **RLS is the authorization layer**
(the client cannot bypass it). Secrets stay server-side (edge functions / RPC
`SECURITY DEFINER`).

## Enums

| Enum | Values |
|------|--------|
| `family_role` | `admin`, `editor`, `contributor`, `relative`, `viewer` |
| `account_status` | `active`, `blocked`, `suspended` |
| `subscription_tier` | `free`, `premium` |
| `rel_type` | `parent` (directed parent→child), `spouse`, `partner` |
| `rel_subtype` | `biological`, `adoptive`, `step`, `foster` |
| `suggestion_status` | `pending`, `approved`, `rejected` |

Role capabilities: **admin** = full family management; **editor** = add/edit
members, relationships, announcements, media; **contributor** = submit
suggestions + post announcements (no direct member writes); **relative** =
view all + self-edit own linked member; **viewer** = read-only.

## Tables (column → type)

### profiles  (account-level; PK `id` → auth.users.id)
`id` uuid · `email` text · `display_name` text · `avatar_url` text ·
`status` account_status='active' · `is_super_admin` bool=false ·
`created_at` timestamptz · `last_active_at` timestamptz
RLS: SELECT/UPDATE own; super-admins SELECT all.

### families  (tenant; PK `id`)
`id` uuid · `name` text · `created_by` uuid · `subscription_tier` tier='free' ·
`settings` jsonb='{}' (`settings.face_recognition` bool) · `created_at` timestamptz
RLS: SELECT members; INSERT auth user as creator; UPDATE admins.

### family_members  (membership; PK (family_id,user_id))
`family_id` uuid · `user_id` uuid · `role` family_role='viewer' ·
`invited_by` uuid · `joined_at` timestamptz
RLS: SELECT members; INSERT/UPDATE/DELETE admins.

### members  (people in the tree; PK `id`)
`id` uuid · `family_id` uuid · `first_name` text NOT NULL · `last_name` text ·
`maiden_name` text · `gender` text · `birth_date` date (YYYY-MM-DD) ·
`death_date` date · `is_living` bool=true · `birth_place` text · `bio` text ·
`phone` text · `address` text · `occupation` text ·
`home_lat`/`home_lng`/`birth_lat`/`birth_lng` double precision (geocoded for the map) ·
`photo_url` text · `avatar_config` jsonb · `linked_user_id` uuid ·
`created_by` uuid · `created_at` · `updated_at` (trigger-touched)
RLS: SELECT members; INSERT/UPDATE/DELETE editors+; relatives UPDATE own (linked_user_id=auth.uid()).
Realtime: yes.

### relationships  (graph edges; PK `id`; unique (family_id,from_member,to_member,type))
`id` uuid · `family_id` uuid · `from_member` uuid · `to_member` uuid ·
`type` rel_type · `subtype` rel_subtype='biological' · `start_date` date ·
`end_date` date · `created_at` · CHECK from≠to
RLS: SELECT members; writes editors+. Realtime: yes.

### announcements  (feed; PK `id`)
`id` uuid · `family_id` uuid · `author_id` uuid · `type` text='news'
(`news|birth|wedding|graduation|memorial|birthday`) · `title` text NOT NULL ·
`body` text · `media_url` text · `created_at`
RLS: SELECT members; INSERT contributors+ (author=uid); DELETE author or admin. Realtime: yes.

### member_media  (memories; PK `id`)
`id` uuid · `family_id` uuid · `member_id` uuid · `uploaded_by` uuid ·
`media_url` text NOT NULL · `caption` text · `created_at`
RLS: SELECT members; INSERT editors+; DELETE uploader or admin. Realtime: yes.

### legacy_capsules  (sealed messages; PK `id`)
`id` uuid · `family_id` uuid · `author_id` uuid · `title` text NOT NULL ·
`body` text · `unlock_at` timestamptz NOT NULL · `created_at`
RLS: **no SELECT** (read via `list_capsules` RPC); INSERT contributors+; DELETE author or admin.

### invitations  (join codes; PK `id`; unique `code`)
`id` uuid · `family_id` uuid · `code` text (8-char hex) · `role` family_role='contributor' ·
`expires_at` timestamptz · `created_by` uuid · `target_member_id` uuid · `created_at`
RLS: SELECT/INSERT admins only.

### edit_suggestions  (contributor proposals; PK `id`)
`id` uuid · `family_id` uuid · `suggested_by` uuid · `kind` text (`add_member|edit_member`) ·
`target_member_id` uuid · `payload` jsonb · `note` text ·
`status` suggestion_status='pending' · `reviewed_by` uuid · `reviewed_at` · `created_at`
RLS: INSERT contributors+; SELECT own or admin; UPDATE admin. Realtime: yes.

### face_embeddings  (pgvector; PK `id`; unique `member_id`)
`id` uuid · `member_id` uuid · `family_id` uuid · `embedding` vector(192) · `created_at`
RLS: SELECT members; writes editors+. (Web app: not used — mobile only.)

### audit_log  (super-admin; PK `id`)
`id` uuid · `actor_id` uuid · `action` text · `target_id` text · `metadata` jsonb · `created_at`
RLS: SELECT super-admins only.

## RPCs (supabase.rpc(name, params))

| Function | Params | Returns | Notes |
|----------|--------|---------|-------|
| `create_family` | `p_name text` | families row | creates family + creator admin membership |
| `is_member_of` | `p_family uuid` | bool | also used in RLS |
| `has_family_role` | `p_family uuid, p_roles family_role[]` | bool | also used in RLS |
| `create_invitation` | `p_family uuid, p_role=contributor, p_expires_in interval='30 days', p_target_member uuid=null` | invitation row | admin only; 8-char code |
| `invite_preview` | `p_code text` | (family_id, family_name, role, valid, target_member_id, target_member_name) | preview without joining |
| `join_family_with_code` | `p_code text` | families row | idempotent; links target member if set |
| `family_roster` | `p_family uuid` | (user_id, role, display_name, email, joined_at) | members only |
| `apply_suggestion` | `p_id uuid` | void | admin; applies add/edit then marks approved |
| `list_capsules` | `p_family uuid` | (id, title, body, unlock_at, author_id, created_at, locked) | body null while locked |
| `set_face_recognition` | `p_family uuid, p_enabled bool` | void | admin; disabling purges embeddings |
| `upsert_face_embedding` | `p_member uuid, p_family uuid, p_embedding text` | void | editors+ (mobile only) |
| `match_face` | `p_family uuid, p_embedding text, p_max_distance float=1.0` | (member_id, distance) | nearest L2 (mobile only) |
| `admin_platform_stats` | — | (total_users, total_families, premium_families, blocked_users) | super-admin |
| `admin_list_families` | — | (id, name, subscription_tier, member_count, person_count, created_at) | super-admin |
| `admin_set_account_status` | `p_user uuid, p_status account_status` | void | super-admin; audited |
| `admin_set_subscription` | `p_family uuid, p_tier subscription_tier` | void | super-admin; audited |

## Storage

- Bucket **`member-photos`** (public read). Path: `{family_id}/{member_id}/avatar_{ts}.jpg`
  and `{family_id}/{member_id}/memories/{ts}.jpg`. Writes: editors+ (or relative on own).
- Upload flow: direct uploads with user JWT fail → call edge function
  **`POST /functions/v1/upload-photo`** (Bearer = session JWT) with
  `{ familyId, memberId, folder: 'avatar'|'memories' }` → returns
  `{ signedUrl, token, path, publicUrl }`; PUT bytes to `signedUrl`; store `publicUrl`.

## Auth (config.toml)

Email/password primary (`enable_signup=true`, `enable_confirmations=false`,
min length 6). Email **OTP** fallback (6-digit, 1h expiry) via
`signInWithOtp({ email, shouldCreateUser })` then `verifyOtp({ email, token, type })`.
JWT 1h, refresh rotation on. No OAuth/MFA/passkeys. **Add the production web
origin (https://www.riza.co.za) to Supabase Auth redirect URLs.**

## Realtime

Publication `supabase_realtime` includes: `members`, `relationships`,
`family_members`, `announcements`, `member_media`, `edit_suggestions`.
Subscribe per family: channel `family:{familyId}`, filter `family_id=eq.{familyId}`,
invalidate the matching query on change. RLS applies to subscribers.

## Core auth/onboarding flows

- **Sign up:** register (email+pw) → (OTP verify if needed) → `create_family` → dashboard.
- **Sign in:** password or "email me a code" (OTP).
- **Join:** `invite_preview(code)` → `join_family_with_code(code)`.
- **Account gate:** block non-`active` profiles (status blocked/suspended).
