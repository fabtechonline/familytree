import type { Member, Relationship } from './types'
import { computeLayout } from './tree-layout'
import { fullName } from './member-utils'

export interface FamilyDNA {
  totalPeople: number
  generations: number
  averageLifespan: number | null
  oldestLivingName: string | null
  oldestLivingAge: number | null
  commonSurname: string | null
  commonSurnameCount: number
  commonFirstName: string | null
  commonFirstNameCount: number
  largestGeneration: number
  birthplaceCount: number
  averageChildren: number | null
}

/** Most-shared value + count, only when something repeats (>=2); ties joined. */
function topShared(values: string[]): { label: string; count: number } | null {
  const counts = new Map<string, number>()
  for (const v of values) {
    const key = v.trim()
    if (!key) continue
    counts.set(key, (counts.get(key) ?? 0) + 1)
  }
  if (counts.size === 0) return null
  const max = Math.max(...counts.values())
  if (max < 2) return null
  const winners = [...counts.entries()].filter(([, c]) => c === max).map(([k]) => k).sort()
  return { label: winners.join(' & '), count: max }
}

/** Mirrors the mobile "Family DNA" insights (insights.dart). */
export function computeFamilyDNA(members: Member[], rels: Relationship[]): FamilyDNA {
  const nowYear = new Date().getFullYear()

  // Average lifespan from members with both birth and death dates.
  const lifespans: number[] = []
  for (const m of members) {
    if (m.birth_date && m.death_date) {
      lifespans.push(new Date(m.death_date).getFullYear() - new Date(m.birth_date).getFullYear())
    }
  }
  const averageLifespan = lifespans.length
    ? Math.round(lifespans.reduce((a, b) => a + b, 0) / lifespans.length)
    : null

  // Oldest living member with a birth date.
  let oldestLivingName: string | null = null
  let oldestLivingAge: number | null = null
  let oldestBirth: number | null = null
  for (const m of members) {
    if (m.is_living && m.birth_date) {
      const y = new Date(m.birth_date).getFullYear()
      if (oldestBirth === null || y < oldestBirth) {
        oldestBirth = y
        oldestLivingName = fullName(m)
        oldestLivingAge = nowYear - y
      }
    }
  }

  const surname = topShared(members.map((m) => m.last_name ?? ''))
  const firstName = topShared(members.map((m) => m.first_name))

  // Generations + largest generation from the layout engine.
  const layout = computeLayout(members, rels)
  const perGen = new Map<number, number>()
  for (const n of layout.nodes.values()) perGen.set(n.gen, (perGen.get(n.gen) ?? 0) + 1)
  const generations = perGen.size ? Math.max(...perGen.keys()) + 1 : 0
  const largestGeneration = perGen.size ? Math.max(...perGen.values()) : 0

  const birthplaceCount = new Set(
    members.map((m) => (m.birth_place ?? '').trim().toLowerCase()).filter(Boolean),
  ).size

  // Average children per parent (only members who are a parent of someone).
  const childrenOf = new Map<string, number>()
  for (const r of rels) {
    if (r.type === 'parent') childrenOf.set(r.from_member, (childrenOf.get(r.from_member) ?? 0) + 1)
  }
  const counts = [...childrenOf.values()]
  const averageChildren = counts.length ? counts.reduce((a, b) => a + b, 0) / counts.length : null

  return {
    totalPeople: members.length,
    generations,
    averageLifespan,
    oldestLivingName,
    oldestLivingAge,
    commonSurname: surname?.label ?? null,
    commonSurnameCount: surname?.count ?? 0,
    commonFirstName: firstName?.label ?? null,
    commonFirstNameCount: firstName?.count ?? 0,
    largestGeneration,
    birthplaceCount,
    averageChildren,
  }
}
