import type { AvatarConfig } from './types'

const DICEBEAR = 'https://api.dicebear.com/9.x'
export const AVATAR_STYLE = 'adventurer'

// Curated option palettes for the builder (hex without '#').
export const SKIN_TONES = ['f2d3b1', 'ecad80', 'eeb592', 'd08b5b', '9e5622', '763900']
export const HAIR_COLORS = ['0e0e0e', '3a2a1d', '6a4e35', '796a45', 'b9a05f', 'e5c07b', 'ac6511', 'cb6820', 'afafaf', 'dba3be']
// A friendly subset of Adventurer hair variants (short + long).
export const HAIR_STYLES = ['short01', 'short02', 'short04', 'short07', 'short11', 'short16', 'long01', 'long07', 'long13', 'long20']

/** Build a DiceBear PNG URL from an avatar config (renders same on web + mobile). */
export function avatarUrl(config: AvatarConfig, size = 160): string {
  const style = config.style || AVATAR_STYLE
  const params = new URLSearchParams()
  params.set('size', String(size))
  if (config.seed) params.set('seed', config.seed)
  for (const [k, v] of Object.entries(config.options ?? {})) {
    if (Array.isArray(v)) v.forEach((x) => params.append(k, String(x)))
    else if (v !== undefined && v !== null && v !== '') params.set(k, String(v))
  }
  return `${DICEBEAR}/${style}/png?${params.toString()}`
}

/** Best image URL for a member: illustrated avatar → photo → null (use initials). */
export function memberImageUrl(
  member: { avatar_config?: AvatarConfig | null; photo_url?: string | null },
  size = 96,
): string | null {
  if (member.avatar_config) return avatarUrl(member.avatar_config, size)
  return member.photo_url ?? null
}

/** A sensible default config seeded by the member id. */
export function defaultAvatarConfig(seed: string): AvatarConfig {
  return { style: AVATAR_STYLE, seed, options: {} }
}
