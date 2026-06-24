import { useMemo } from 'react'
import type { Member, Relationship } from '../lib/types'

const R0 = 58 // centre disc radius (focus person)
const RING = 82 // thickness of each ancestor ring
const MAX_GEN = 4 // ancestor rings beyond the focus
const PAD = 16

/** Father first, then mother (by gender; falls back to recorded order). */
function orderedParents(id: string, parentsOf: Map<string, string[]>, byId: Map<string, Member>) {
  const ps = (parentsOf.get(id) ?? []).map((p) => byId.get(p)).filter(Boolean) as Member[]
  const father = ps.find((p) => p.gender === 'male')
  const mother = ps.find((p) => p.gender === 'female')
  if (father || mother) return [father, mother] as (Member | undefined)[]
  return [ps[0], ps[1]]
}

function sectorPath(cx: number, cy: number, rIn: number, rOut: number, a0: number, a1: number) {
  const pt = (r: number, a: number) => [cx + r * Math.cos(a), cy + r * Math.sin(a)]
  const [x0, y0] = pt(rOut, a0)
  const [x1, y1] = pt(rOut, a1)
  const [x2, y2] = pt(rIn, a1)
  const [x3, y3] = pt(rIn, a0)
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${x0} ${y0} A${rOut} ${rOut} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${rIn} ${rIn} 0 ${large} 0 ${x3} ${y3} Z`
}

/** Radial ancestor fan: focus person at centre, ancestors fanning up in arcs. */
export default function FanChart({
  members, rels, focusId, onSelect,
}: {
  members: Member[]
  rels: Relationship[]
  focusId: string
  onSelect: (m: Member, e: React.MouseEvent) => void
}) {
  const { byId, parentsOf } = useMemo(() => {
    const byId = new Map(members.map((m) => [m.id, m]))
    const parentsOf = new Map<string, string[]>()
    for (const r of rels) if (r.type === 'parent') {
      ;(parentsOf.get(r.to_member) ?? parentsOf.set(r.to_member, []).get(r.to_member)!).push(r.from_member)
    }
    return { byId, parentsOf }
  }, [members, rels])

  const focus = byId.get(focusId)
  const Rmax = R0 + MAX_GEN * RING
  const cx = Rmax + PAD
  const cy = Rmax + PAD
  const W = 2 * (Rmax + PAD)
  const H = Rmax + R0 + 2 * PAD

  // ancestor at generation g, slot k (Ahnentafel: bits choose father/mother).
  const ancestorAt = (g: number, k: number): Member | undefined => {
    let cur: Member | undefined = focus
    for (let i = 0; i < g; i++) {
      if (!cur) return undefined
      const bit = (k >> (g - 1 - i)) & 1
      cur = orderedParents(cur.id, parentsOf, byId)[bit]
    }
    return cur
  }

  const wedges: React.ReactNode[] = []
  for (let g = 1; g <= MAX_GEN; g++) {
    const slots = 1 << g
    const rIn = R0 + (g - 1) * RING
    const rOut = R0 + g * RING
    for (let k = 0; k < slots; k++) {
      const a0 = Math.PI + (k / slots) * Math.PI
      const a1 = Math.PI + ((k + 1) / slots) * Math.PI
      const m = ancestorAt(g, k)
      const mid = (a0 + a1) / 2
      const rMid = (rIn + rOut) / 2
      const tx = cx + rMid * Math.cos(mid)
      const ty = cy + rMid * Math.sin(mid)
      let deg = (mid * 180) / Math.PI + 90
      if (deg > 90 && deg < 270) deg -= 180 // keep text upright
      wedges.push(
        <g key={`${g}-${k}`} className={m ? 'cursor-pointer' : ''} onClick={m ? (e) => onSelect(m, e) : undefined}>
          <path d={sectorPath(cx, cy, rIn, rOut, a0, a1)} fill={m ? (k % 2 ? '#E8F7F4' : '#F3FBF9') : '#F7F7F7'} stroke="#fff" strokeWidth={2} />
          {m && (
            <text x={tx} y={ty} transform={`rotate(${deg} ${tx} ${ty})`} textAnchor="middle" dominantBaseline="central" fontSize={g >= 3 ? 9 : 11} fontWeight={600} fill="#0F3D3A">
              {(m.first_name || '?') + (m.last_name ? ` ${m.last_name[0]}.` : '')}
            </text>
          )}
        </g>,
      )
    }
  }

  if (!focus) return null
  return (
    <div className="grid h-full w-full place-items-center overflow-auto p-4">
      <svg viewBox={`0 0 ${W} ${H}`} className="max-h-full max-w-full" style={{ width: Math.min(W, 920) }}>
        {wedges}
        <circle cx={cx} cy={cy} r={R0} fill="#1FB6A6" className="cursor-pointer" onClick={(e) => onSelect(focus, e)} />
        <text x={cx} y={cy} textAnchor="middle" dominantBaseline="central" fontSize={14} fontWeight={800} fill="#fff">
          {focus.first_name}
        </text>
      </svg>
    </div>
  )
}
