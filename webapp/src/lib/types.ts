// Domain types mirroring the Riza Supabase schema (see docs/backend-contract.md).

export type FamilyRole = 'admin' | 'editor' | 'contributor' | 'relative' | 'viewer'
export type AccountStatus = 'active' | 'blocked' | 'suspended'
export type SubscriptionTier = 'free' | 'premium'
export type RelType = 'parent' | 'spouse' | 'partner'
export type RelSubtype = 'biological' | 'adoptive' | 'step' | 'foster'
export type SuggestionStatus = 'pending' | 'approved' | 'rejected'
export interface Memory {
  id: string
  family_id: string
  member_id: string
  media_url: string
  caption?: string | null
  uploaded_by?: string | null
  created_at: string
}

export type AnnouncementType =
  | 'news' | 'birthday' | 'birth' | 'wedding' | 'anniversary' | 'engagement'
  | 'graduation' | 'new_job' | 'new_home' | 'achievement' | 'reunion'
  | 'travel' | 'memorial'

export interface Profile {
  id: string
  email?: string
  display_name?: string
  avatar_url?: string
  status: AccountStatus
  is_super_admin: boolean
  created_at: string
  last_active_at?: string
}

export interface Family {
  id: string
  name: string
  created_by: string
  subscription_tier: SubscriptionTier
  settings: { face_recognition?: boolean; [k: string]: unknown }
  created_at: string
  is_suspended?: boolean
  suspended_reason?: string | null
  member_limit?: number | null
}

/** Illustrated avatar config (DiceBear). Stored in members.avatar_config. */
export interface AvatarConfig {
  style: string // e.g. 'adventurer'
  seed?: string
  options?: Record<string, string | number | boolean | string[]>
}

export interface Member {
  id: string
  family_id: string
  first_name: string
  last_name?: string | null
  maiden_name?: string | null
  gender?: string | null
  birth_date?: string | null
  death_date?: string | null
  is_living: boolean
  birth_place?: string | null
  bio?: string | null
  phone?: string | null
  address?: string | null
  occupation?: string | null
  home_lat?: number | null
  home_lng?: number | null
  birth_lat?: number | null
  birth_lng?: number | null
  photo_url?: string | null
  avatar_config?: AvatarConfig | null
  linked_user_id?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export interface Relationship {
  id: string
  family_id: string
  from_member: string
  to_member: string
  type: RelType
  subtype: RelSubtype
  start_date?: string | null
  end_date?: string | null
  created_at: string
}

export interface Announcement {
  id: string
  family_id: string
  author_id: string
  type: AnnouncementType
  title: string
  body?: string | null
  media_url?: string | null
  created_at: string
}

export interface Capsule {
  id: string
  title: string
  body?: string | null
  unlock_at: string
  author_id: string
  created_at: string
  locked: boolean
}

export interface RosterMember {
  user_id: string
  role: FamilyRole
  display_name?: string | null
  email?: string | null
  joined_at: string
}

export interface InvitePreview {
  family_id: string
  family_name: string
  role: FamilyRole
  valid: boolean
  target_member_id?: string | null
  target_member_name?: string | null
}

export interface EditSuggestion {
  id: string
  family_id: string
  suggested_by: string
  kind: 'add_member' | 'edit_member'
  target_member_id?: string | null
  payload: Record<string, unknown>
  note?: string | null
  status: SuggestionStatus
  reviewed_by?: string | null
  reviewed_at?: string | null
  created_at: string
}

// Role capability helpers
export const canEdit = (r?: FamilyRole) => r === 'admin' || r === 'editor'
export const isAdmin = (r?: FamilyRole) => r === 'admin'
export const canContribute = (r?: FamilyRole) =>
  r === 'admin' || r === 'editor' || r === 'contributor'
