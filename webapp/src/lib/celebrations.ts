import type { Member, Relationship } from './types'
import { fullName } from './member-utils'

export interface Celebration {
  kind: 'birthday' | 'anniversary'
  date: Date // next occurrence
  daysUntil: number
  title: string
  subtitle: string
  turning?: number // age / years married
  memberIds: string[]
}

function nextOccurrence(month: number, day: number, from: Date): { date: Date; days: number } {
  const year = from.getFullYear()
  let d = new Date(year, month, day)
  const today = new Date(from.getFullYear(), from.getMonth(), from.getDate())
  if (d < today) d = new Date(year + 1, month, day)
  const days = Math.round((d.getTime() - today.getTime()) / 86_400_000)
  return { date: d, days }
}

/** Upcoming birthdays (living members) + wedding anniversaries (active unions). */
export function upcomingCelebrations(
  members: Member[],
  rels: Relationship[],
  withinDays = 366,
): Celebration[] {
  const now = new Date()
  const byId = new Map(members.map((m) => [m.id, m]))
  const out: Celebration[] = []

  for (const m of members) {
    if (!m.is_living || !m.birth_date) continue
    const b = new Date(m.birth_date)
    if (isNaN(b.getTime())) continue
    const { date, days } = nextOccurrence(b.getMonth(), b.getDate(), now)
    if (days > withinDays) continue
    out.push({
      kind: 'birthday',
      date,
      daysUntil: days,
      title: `${fullName(m)}’s birthday`,
      subtitle: date.toLocaleDateString(undefined, { month: 'long', day: 'numeric' }),
      turning: date.getFullYear() - b.getFullYear(),
      memberIds: [m.id],
    })
  }

  for (const r of rels) {
    if (r.type !== 'spouse' && r.type !== 'partner') continue
    if (!r.start_date || r.end_date) continue
    const s = new Date(r.start_date)
    if (isNaN(s.getTime())) continue
    const a = byId.get(r.from_member)
    const b = byId.get(r.to_member)
    if (!a || !b) continue
    const { date, days } = nextOccurrence(s.getMonth(), s.getDate(), now)
    if (days > withinDays) continue
    out.push({
      kind: 'anniversary',
      date,
      daysUntil: days,
      title: `${a.first_name} & ${b.first_name}’s anniversary`,
      subtitle: date.toLocaleDateString(undefined, { month: 'long', day: 'numeric' }),
      turning: date.getFullYear() - s.getFullYear(),
      memberIds: [a.id, b.id],
    })
  }

  return out.sort((x, y) => x.daysUntil - y.daysUntil)
}
