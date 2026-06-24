import type { Member, Relationship } from './types'

export const NODE_W = 150
export const NODE_H = 64
export const GEN_GAP = 96 // gap between generations along the depth axis
export const SPOUSE_GAP = 22 // gap between partners inside a couple
export const UNIT_GAP = 44 // gap between sibling units (cross axis)

export type Orientation = 'vertical' | 'horizontal'

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
  // elbow from the parents' midpoint to a child, routed via a "bus" at mid-depth
  px: number
  py: number
  cx: number
  cy: number
  bus: number // depth-axis coordinate of the bus (Y when vertical, X when horizontal)
  childId: string
  parentIds: string[]
}

export interface TreeLayout {
  nodes: Map<string, PositionedNode>
  couples: CoupleLink[]
  parents: ParentLink[]
  width: number
  height: number
  orientation: Orientation
}

interface Unit {
  ids: string[] // members placed along the cross axis (a couple or a single)
  gen: number
  x: number // left edge along the cross axis
  width: number // extent along the cross axis
}

export function computeLayout(
  members: Member[],
  rels: Relationship[],
  orientation: Orientation = 'vertical',
): TreeLayout {
  const vertical = orientation === 'vertical'
  const crossSize = vertical ? NODE_W : NODE_H // a node's extent along the cross axis
  const depthStep = (vertical ? NODE_H : NODE_W) + GEN_GAP

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

  // 1) Generation assignment — relax until stable.
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
    group.sort((a, b) => (byId.get(a)!.first_name || '').localeCompare(byId.get(b)!.first_name || ''))
    const unit: Unit = {
      ids: group,
      gen: gen.get(m.id)!,
      x: 0,
      width: group.length * crossSize + (group.length - 1) * SPOUSE_GAP,
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
    for (let i = 0; i < row.length; i++) {
      const u = row[i]
      const target = bary(u)
      if (!isFinite(target)) continue
      const desiredX = target - u.width / 2
      const minX = i === 0 ? -Infinity : row[i - 1].x + row[i - 1].width + UNIT_GAP
      u.x = Math.max(minX, desiredX)
    }
  }

  // 4) Emit node positions — map (cross, depth) → (x, y) by orientation.
  const place = (cross: number, depth: number) =>
    vertical ? { x: cross, y: depth } : { x: depth, y: cross }
  const nodes = new Map<string, PositionedNode>()
  for (const u of units) {
    let cross = u.x
    for (const id of u.ids) {
      const { x, y } = place(cross, u.gen * depthStep)
      nodes.set(id, { member: byId.get(id)!, x, y, gen: u.gen })
      cross += crossSize + SPOUSE_GAP
    }
  }

  // 5) Couple links — between adjacent partners in a unit.
  const couples: CoupleLink[] = []
  for (const u of units) {
    for (let i = 0; i + 1 < u.ids.length; i++) {
      const a = nodes.get(u.ids[i])!
      const b = nodes.get(u.ids[i + 1])!
      if (vertical) {
        couples.push({ ax: a.x + NODE_W, ay: a.y + NODE_H / 2, bx: b.x, by: b.y + NODE_H / 2, aId: u.ids[i], bId: u.ids[i + 1] })
      } else {
        couples.push({ ax: a.x + NODE_W / 2, ay: a.y + NODE_H, bx: b.x + NODE_W / 2, by: b.y, aId: u.ids[i], bId: u.ids[i + 1] })
      }
    }
  }

  // 6) Parent→child elbows.
  const parents: ParentLink[] = []
  for (const m of members) {
    const ps = parentsOf.get(m.id)!.map((p) => nodes.get(p)!).filter(Boolean)
    if (ps.length === 0) continue
    const child = nodes.get(m.id)!
    if (vertical) {
      const px = ps.reduce((s, p) => s + p.x + NODE_W / 2, 0) / ps.length
      const py = Math.max(...ps.map((p) => p.y)) + NODE_H
      parents.push({ px, py, cx: child.x + NODE_W / 2, cy: child.y, bus: py + GEN_GAP / 2, childId: m.id, parentIds: parentsOf.get(m.id)!.filter((p) => nodes.has(p)) })
    } else {
      const py = ps.reduce((s, p) => s + p.y + NODE_H / 2, 0) / ps.length
      const px = Math.max(...ps.map((p) => p.x)) + NODE_W
      parents.push({ px, py, cx: child.x, cy: child.y + NODE_H / 2, bus: px + GEN_GAP / 2, childId: m.id, parentIds: parentsOf.get(m.id)!.filter((p) => nodes.has(p)) })
    }
  }

  // 7) Normalize to positive coordinates + bounds (both axes).
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (const n of nodes.values()) {
    minX = Math.min(minX, n.x)
    minY = Math.min(minY, n.y)
    maxX = Math.max(maxX, n.x + NODE_W)
    maxY = Math.max(maxY, n.y + NODE_H)
  }
  if (!isFinite(minX)) { minX = 0; maxX = 0; minY = 0; maxY = 0 }
  const pad = 60
  const sx = -minX + pad
  const sy = -minY + pad
  const busShift = vertical ? sy : sx
  for (const n of nodes.values()) { n.x += sx; n.y += sy }
  for (const c of couples) { c.ax += sx; c.bx += sx; c.ay += sy; c.by += sy }
  for (const p of parents) { p.px += sx; p.cx += sx; p.py += sy; p.cy += sy; p.bus += busShift }

  return {
    nodes,
    couples,
    parents,
    width: maxX - minX + pad * 2,
    height: maxY - minY + pad * 2,
    orientation,
  }
}
