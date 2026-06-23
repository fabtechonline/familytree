import type { Member, Relationship } from './types'
import { shortestPath } from './relationships'
import { describeKinship } from './kinship'

export interface Lineage {
  selectedId: string
  members: Set<string> // selected + all highlighted relatives
  labels: Map<string, string> // relativeId -> capitalized relationship
  unionMembers: Set<string> // spouse bar highlights if either end here
  descentChildIds: Set<string> // a child's up-link highlights if child here
  descentParentIds: Set<string> // a parent's down-links highlight if parent here
}

interface Graph {
  parentsOf: Map<string, string[]>
  childrenOf: Map<string, string[]>
  spousesOf: Map<string, string[]>
}

function buildGraph(members: Member[], rels: Relationship[]): Graph {
  const parentsOf = new Map<string, string[]>()
  const childrenOf = new Map<string, string[]>()
  const spousesOf = new Map<string, string[]>()
  for (const m of members) {
    parentsOf.set(m.id, [])
    childrenOf.set(m.id, [])
    spousesOf.set(m.id, [])
  }
  for (const r of rels) {
    if (r.type === 'parent') {
      childrenOf.get(r.from_member)?.push(r.to_member)
      parentsOf.get(r.to_member)?.push(r.from_member)
    } else {
      spousesOf.get(r.from_member)?.push(r.to_member)
      spousesOf.get(r.to_member)?.push(r.from_member)
    }
  }
  return { parentsOf, childrenOf, spousesOf }
}

function ancestors(g: Graph, id: string): Set<string> {
  const out = new Set<string>()
  const queue = [id]
  while (queue.length) {
    const cur = queue.shift()!
    for (const p of g.parentsOf.get(cur) ?? []) if (!out.has(p)) { out.add(p); queue.push(p) }
  }
  return out
}
function descendants(g: Graph, id: string): Set<string> {
  const out = new Set<string>()
  const queue = [id]
  while (queue.length) {
    const cur = queue.shift()!
    for (const c of g.childrenOf.get(cur) ?? []) if (!out.has(c)) { out.add(c); queue.push(c) }
  }
  return out
}

const cap = (s: string) => (s ? s[0].toUpperCase() + s.slice(1) : s)

/** Highlight sets for "View lineage" — mirrors the Android computeLineage. */
export function computeLineage(
  members: Member[],
  rels: Relationship[],
  selectedId: string,
  full = false,
): Lineage {
  const g = buildGraph(members, rels)
  const parents = new Set(g.parentsOf.get(selectedId) ?? [])
  const spouses = new Set(g.spousesOf.get(selectedId) ?? [])
  const children = new Set(g.childrenOf.get(selectedId) ?? [])

  const siblings = new Set<string>()
  for (const p of parents) {
    for (const c of g.childrenOf.get(p) ?? []) if (c !== selectedId) siblings.add(c)
  }

  let descentChildIds: Set<string>
  let descentParentIds: Set<string>
  let related: Set<string>

  if (full) {
    const anc = ancestors(g, selectedId)
    const desc = descendants(g, selectedId)
    descentChildIds = new Set([selectedId, ...anc, ...siblings])
    descentParentIds = new Set([selectedId, ...desc])
    related = new Set([...parents, ...siblings, ...spouses, ...children, ...anc, ...desc])
  } else {
    descentChildIds = new Set([selectedId, ...siblings])
    descentParentIds = new Set([selectedId])
    related = new Set([...parents, ...siblings, ...spouses, ...children])
  }

  const membersSet = new Set([selectedId, ...related])
  const unionMembers = full ? membersSet : new Set([selectedId, ...spouses])

  const labels = new Map<string, string>()
  for (const id of related) {
    const path = shortestPath(selectedId, id, rels)
    if (path && path.length) labels.set(id, cap(describeKinship(path)))
  }

  return { selectedId, members: membersSet, labels, unionMembers, descentChildIds, descentParentIds }
}
