import type { Member, Relationship } from './types'

export interface Relations {
  parents: Member[]
  children: Member[]
  partners: Member[]
  siblings: Member[]
}

const byId = (members: Member[]) => {
  const m = new Map<string, Member>()
  for (const x of members) m.set(x.id, x)
  return m
}

/** Immediate relations for a member, derived from relationship edges. */
export function getRelations(
  memberId: string,
  members: Member[],
  rels: Relationship[],
): Relations {
  const map = byId(members)
  const parents: Member[] = []
  const children: Member[] = []
  const partners: Member[] = []

  for (const r of rels) {
    if (r.type === 'parent') {
      if (r.to_member === memberId && map.has(r.from_member)) parents.push(map.get(r.from_member)!)
      if (r.from_member === memberId && map.has(r.to_member)) children.push(map.get(r.to_member)!)
    } else {
      // spouse | partner (undirected)
      if (r.from_member === memberId && map.has(r.to_member)) partners.push(map.get(r.to_member)!)
      else if (r.to_member === memberId && map.has(r.from_member)) partners.push(map.get(r.from_member)!)
    }
  }

  // Siblings: share at least one parent (excluding self).
  const myParentIds = new Set(parents.map((p) => p.id))
  const siblingIds = new Set<string>()
  for (const r of rels) {
    if (r.type === 'parent' && myParentIds.has(r.from_member) && r.to_member !== memberId) {
      siblingIds.add(r.to_member)
    }
  }
  const siblings = [...siblingIds].map((id) => map.get(id)).filter((m): m is Member => !!m)

  return { parents, children, partners, siblings }
}

/** BFS shortest relationship path between two members (for "How related?"). */
export function shortestPath(
  fromId: string,
  toId: string,
  rels: Relationship[],
): { id: string; via: 'parent' | 'child' | 'partner' }[] | null {
  const adj = new Map<string, { id: string; via: 'parent' | 'child' | 'partner' }[]>()
  const push = (a: string, b: string, via: 'parent' | 'child' | 'partner') => {
    if (!adj.has(a)) adj.set(a, [])
    adj.get(a)!.push({ id: b, via })
  }
  for (const r of rels) {
    if (r.type === 'parent') {
      push(r.from_member, r.to_member, 'child')
      push(r.to_member, r.from_member, 'parent')
    } else {
      push(r.from_member, r.to_member, 'partner')
      push(r.to_member, r.from_member, 'partner')
    }
  }
  const queue: string[] = [fromId]
  const prev = new Map<string, { id: string; via: 'parent' | 'child' | 'partner' }>()
  const seen = new Set([fromId])
  while (queue.length) {
    const cur = queue.shift()!
    if (cur === toId) break
    for (const edge of adj.get(cur) ?? []) {
      if (!seen.has(edge.id)) {
        seen.add(edge.id)
        prev.set(edge.id, { id: cur, via: edge.via })
        queue.push(edge.id)
      }
    }
  }
  if (!prev.has(toId) && fromId !== toId) return null
  const path: { id: string; via: 'parent' | 'child' | 'partner' }[] = []
  let node = toId
  while (node !== fromId) {
    const p = prev.get(node)
    if (!p) break
    path.unshift({ id: node, via: p.via })
    node = p.id
  }
  return path
}
