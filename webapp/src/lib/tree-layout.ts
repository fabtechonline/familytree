import type { Member, Relationship } from './types'

export const NODE_W = 150
export const NODE_H = 64
export const GEN_GAP = 96 // vertical space between generation rows
export const SPOUSE_GAP = 22 // gap between partners inside a couple
export const UNIT_GAP = 44 // gap between sibling units

export interface PositionedNode {
  member: Member
  x: number
  y: number
  gen: number
}

export interface CoupleLink {
  ax: number
  ay: number
  bx: number
  by: number
  aId: string
  bId: string
}

export interface ParentLink {
  // elbow from parents' midpoint to a child
  px: number
  py: number
  cx: number
  cy: number
  busY: number
  childId: string
  parentIds: string[]
}

export interface TreeLayout {
  nodes: Map<string, PositionedNode>
  couples: CoupleLink[]
  parents: ParentLink[]
  width: number
  height: number
}

interface Unit {
  ids: string[] // members placed left→right (a couple or a single)
  gen: number
  x: number // left edge
  width: number
}

export function computeLayout(members: Member[], rels: Relationship[]): TreeLayout {
  const byId = new Map(members.map((m) => [m.id, m]))
  const parentsOf = new Map<string, string[]>()
  const partnersOf = new Map<string, string[]>()
  for (const m of members) {
    parentsOf.set(m.id, [])
    partnersOf.set(m.id, [])
  }
  for (const r of rels) {
    if (!byId.has(r.from_member) || !byId.has(r.to_member)) continue
    if (r.type === 'parent') {
      parentsOf.get(r.to_member)!.push(r.from_member)
    } else {
      partnersOf.get(r.from_member)!.push(r.to_member)
      partnersOf.get(r.to_member)!.push(r.from_member)
    }
  }

  // 1) Generation assignment — relax until stable: children below parents, partners aligned.
  const gen = new Map<string, number>(members.map((m) => [m.id, 0]))
  for (let iter = 0; iter < members.length + 2; iter++) {
    let changed = false
    for (const m of members) {
      const ps = parentsOf.get(m.id)!
      if (ps.length) {
        const want = Math.max(...ps.map((p) => gen.get(p)!)) + 1
        if (gen.get(m.id)! < want) {
          gen.set(m.id, want)
          changed = true
        }
      }
    }
    for (const m of members) {
      for (const p of partnersOf.get(m.id)!) {
        const mx = Math.max(gen.get(m.id)!, gen.get(p)!)
        if (gen.get(m.id)! !== mx || gen.get(p)! !== mx) {
          gen.set(m.id, mx)
          gen.set(p, mx)
          changed = true
        }
      }
    }
    if (!changed) break
  }

  // 2) Couple units — connected components of same-generation partners.
  const unitOf = new Map<string, Unit>()
  const units: Unit[] = []
  const visited = new Set<string>()
  for (const m of members) {
    if (visited.has(m.id)) continue
    const group: string[] = []
    const stack = [m.id]
    while (stack.length) {
      const cur = stack.pop()!
      if (visited.has(cur)) continue
      visited.add(cur)
      group.push(cur)
      for (const p of partnersOf.get(cur)!) {
        if (!visited.has(p) && gen.get(p) === gen.get(m.id)) stack.push(p)
      }
    }
    // order group so the "blood" member (with parents in tree) sits sensibly; keep stable by name
    group.sort((a, b) => (byId.get(a)!.first_name || '').localeCompare(byId.get(b)!.first_name || ''))
    const unit: Unit = {
      ids: group,
      gen: gen.get(m.id)!,
      x: 0,
      width: group.length * NODE_W + (group.length - 1) * SPOUSE_GAP,
    }
    units.push(unit)
    for (const id of group) unitOf.set(id, unit)
  }

  // 3) Order + position units generation by generation (barycenter of parents).
  const maxGen = Math.max(0, ...units.map((u) => u.gen))
  const centerX = (u: Unit) => u.x + u.width / 2

  for (let g = 0; g <= maxGen; g++) {
    const row = units.filter((u) => u.gen === g)
    const bary = (u: Unit): number => {
      const parentUnits = new Set<Unit>()
      for (const id of u.ids) {
        for (const p of parentsOf.get(id)!) {
          const pu = unitOf.get(p)
          if (pu && pu.gen < g) parentUnits.add(pu)
        }
      }
      if (parentUnits.size === 0) return Number.POSITIVE_INFINITY
      let sum = 0
      for (const pu of parentUnits) sum += centerX(pu)
      return sum / parentUnits.size
    }
    row.sort((a, b) => {
      const ba = bary(a)
      const bb = bary(b)
      if (ba === bb) return a.ids[0].localeCompare(b.ids[0])
      return ba - bb
    })
    let cursor = 0
    for (const u of row) {
      u.x = cursor
      cursor += u.width + UNIT_GAP
    }
    // nudge each unit toward its parents' barycenter where there's room (single pass)
    for (let i = 0; i < row.length; i++) {
      const u = row[i]
      const target = bary(u)
      if (!isFinite(target)) continue
      const desiredX = target - u.width / 2
      const minX = i === 0 ? -Infinity : row[i - 1].x + row[i - 1].width + UNIT_GAP
      u.x = Math.max(minX, desiredX)
    }
  }

  // 4) Emit node positions.
  const nodes = new Map<string, PositionedNode>()
  for (const u of units) {
    let nx = u.x
    for (const id of u.ids) {
      nodes.set(id, { member: byId.get(id)!, x: nx, y: u.gen * (NODE_H + GEN_GAP), gen: u.gen })
      nx += NODE_W + SPOUSE_GAP
    }
  }

  // 5) Couple links (between adjacent partners in a unit).
  const couples: CoupleLink[] = []
  for (const u of units) {
    for (let i = 0; i + 1 < u.ids.length; i++) {
      const a = nodes.get(u.ids[i])!
      const b = nodes.get(u.ids[i + 1])!
      couples.push({
        ax: a.x + NODE_W, ay: a.y + NODE_H / 2, bx: b.x, by: b.y + NODE_H / 2,
        aId: u.ids[i], bId: u.ids[i + 1],
      })
    }
  }

  // 6) Parent→child elbows. Anchor at parents' midpoint.
  const parents: ParentLink[] = []
  for (const m of members) {
    const ps = parentsOf.get(m.id)!.map((p) => nodes.get(p)!).filter(Boolean)
    if (ps.length === 0) continue
    const child = nodes.get(m.id)!
    const px = ps.reduce((s, p) => s + p.x + NODE_W / 2, 0) / ps.length
    const py = Math.max(...ps.map((p) => p.y)) + NODE_H
    const busY = py + GEN_GAP / 2
    parents.push({
      px, py, cx: child.x + NODE_W / 2, cy: child.y, busY,
      childId: m.id, parentIds: parentsOf.get(m.id)!.filter((p) => nodes.has(p)),
    })
  }

  // 7) Normalize to positive coordinates + bounds.
  let minX = Infinity
  let maxX = -Infinity
  let maxY = 0
  for (const n of nodes.values()) {
    minX = Math.min(minX, n.x)
    maxX = Math.max(maxX, n.x + NODE_W)
    maxY = Math.max(maxY, n.y + NODE_H)
  }
  if (!isFinite(minX)) {
    minX = 0
    maxX = 0
  }
  const pad = 60
  const shift = -minX + pad
  for (const n of nodes.values()) n.x += shift
  for (const c of couples) {
    c.ax += shift
    c.bx += shift
  }
  for (const p of parents) {
    p.px += shift
    p.cx += shift
  }

  return {
    nodes,
    couples,
    parents,
    width: maxX - minX + pad * 2,
    height: maxY + pad,
  }
}
