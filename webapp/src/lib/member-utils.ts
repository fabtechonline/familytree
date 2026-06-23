import type { Member } from './types'

export const fullName = (m: Pick<Member, 'first_name' | 'last_name'>) =>
  [m.first_name, m.last_name].filter(Boolean).join(' ').trim()

export const initials = (m: Pick<Member, 'first_name' | 'last_name'>) =>
  [m.first_name?.[0], m.last_name?.[0]].filter(Boolean).join('').toUpperCase() || '?'

/** Deterministic brand-palette colour for an avatar fallback. */
export function avatarColor(id: string): string {
  const palette = ['#1FB6A6', '#4D9DE0', '#FF7E6B', '#FFC857', '#149286']
  let h = 0
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0
  return palette[h % palette.length]
}

/** Age (or age at death) in whole years, or null if no birth date. */
export function ageOf(m: Pick<Member, 'birth_date' | 'death_date'>): number | null {
  if (!m.birth_date) return null
  const birth = new Date(m.birth_date)
  const end = m.death_date ? new Date(m.death_date) : new Date()
  let age = end.getFullYear() - birth.getFullYear()
  const md = end.getMonth() - birth.getMonth()
  if (md < 0 || (md === 0 && end.getDate() < birth.getDate())) age--
  return age >= 0 ? age : null
}

export function formatDate(d?: string | null): string {
  if (!d) return ''
  const date = new Date(d)
  if (isNaN(date.getTime())) return d
  return date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}
