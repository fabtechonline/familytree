import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../auth/AuthProvider'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { computeLayout, NODE_W, NODE_H } from '../../lib/tree-layout'
import { computeLineage, type Lineage } from '../../lib/lineage'
import { fullName, ageOf } from '../../lib/member-utils'
import { canEdit as roleCanEdit } from '../../lib/types'
import { Spinner, EmptyState } from '../../components/ui'
import Avatar from '../../components/Avatar'
import Icon from '../../components/Icon'
import type { Member } from '../../lib/types'

// Filled heart (24×24 viewBox), drawn at each spouse-link midpoint.
const HEART =
  'M12 21s-7-4.4-9.5-8.4C1 9.9 2.4 6.5 5.8 6.5c2 0 3.4 1.2 4.2 2.4.8-1.2 2.2-2.4 4.2-2.4 3.4 0 4.8 3.4 3.3 6.1C19 16.6 12 21 12 21z'

interface MenuState {
  member: Member
  x: number
  y: number
}

export default function TreePage() {
  const { current } = useFamily()
  const { session } = useAuth()
  const myUid = session?.user.id
  const nav = useNavigate()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [], isLoading: relLoading } = useRelationships(current?.id)

  const layout = useMemo(() => computeLayout(members, rels), [members, rels])

  const [menu, setMenu] = useState<MenuState | null>(null)
  const [lineageOf, setLineageOf] = useState<string | null>(null)
  const [full, setFull] = useState(false)

  const lineage: Lineage | null = useMemo(
    () => (lineageOf ? computeLineage(members, rels, lineageOf, full) : null),
    [members, rels, lineageOf, full],
  )

  const wrapRef = useRef<HTMLDivElement>(null)
  const [view, setView] = useState({ x: 0, y: 0, scale: 1 })
  const drag = useRef<{ x: number; y: number; vx: number; vy: number; moved: boolean } | null>(null)

  useEffect(() => {
    const el = wrapRef.current
    if (!el || layout.nodes.size === 0) return
    const cw = el.clientWidth
    const ch = el.clientHeight
    const scale = Math.min(1, Math.min(cw / layout.width, ch / layout.height) * 0.95)
    setView({ x: (cw - layout.width * scale) / 2, y: 24, scale })
  }, [layout])

  const onWheel = (e: React.WheelEvent) => {
    e.preventDefault()
    const rect = wrapRef.current!.getBoundingClientRect()
    const mx = e.clientX - rect.left
    const my = e.clientY - rect.top
    setView((v) => {
      const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1
      const scale = Math.min(2.5, Math.max(0.15, v.scale * factor))
      const k = scale / v.scale
      return { scale, x: mx - (mx - v.x) * k, y: my - (my - v.y) * k }
    })
  }
  const onPointerDown = (e: React.PointerEvent) => {
    drag.current = { x: e.clientX, y: e.clientY, vx: view.x, vy: view.y, moved: false }
  }
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current) return
    const dx = e.clientX - drag.current.x
    const dy = e.clientY - drag.current.y
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) drag.current.moved = true
    setView((v) => ({ ...v, x: drag.current!.vx + dx, y: drag.current!.vy + dy }))
  }
  const onPointerUp = () => {
    drag.current = null
  }
  const zoom = (factor: number) =>
    setView((v) => ({ ...v, scale: Math.min(2.5, Math.max(0.15, v.scale * factor)) }))

  const openMenu = (member: Member, e: React.MouseEvent) => {
    if (drag.current?.moved) return // was a pan, not a tap
    setMenu({ member, x: e.clientX, y: e.clientY })
  }

  if (isLoading || relLoading) return <Spinner />
  if (members.length === 0) {
    return <EmptyState icon="tree" title="Your tree is empty" body="Add members and link relationships to see your family tree." />
  }

  // Edge highlight helpers
  const descentHi = (childId: string, parentIds: string[]) =>
    !!lineage &&
    (lineage.descentChildIds.has(childId) || parentIds.some((p) => lineage.descentParentIds.has(p)))
  const unionHi = (aId: string, bId: string) =>
    !!lineage && (lineage.unionMembers.has(aId) || lineage.unionMembers.has(bId))

  return (
    <div className="relative h-[calc(100vh-7rem)] rounded-2xl border border-black/5 bg-white overflow-hidden">
      <div className="absolute z-10 top-4 left-4 rounded-pill bg-white/90 backdrop-blur border border-black/5 px-4 py-1.5 shadow-card">
        <h1 className="font-extrabold">{current?.name}</h1>
      </div>
      <div className="absolute z-10 top-4 right-4 flex flex-col gap-2">
        <button onClick={() => zoom(1.2)} className="h-9 w-9 rounded-lg bg-white border border-black/10 grid place-items-center hover:border-brand/40 text-lg font-bold">+</button>
        <button onClick={() => zoom(1 / 1.2)} className="h-9 w-9 rounded-lg bg-white border border-black/10 grid place-items-center hover:border-brand/40 text-lg font-bold">–</button>
      </div>

      <div
        ref={wrapRef}
        className="absolute inset-0 cursor-grab active:cursor-grabbing touch-none"
        onWheel={onWheel}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerLeave={onPointerUp}
      >
        <div
          className="absolute top-0 left-0 origin-top-left"
          style={{ width: layout.width, height: layout.height, transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})` }}
        >
          <svg width={layout.width} height={layout.height} className="absolute inset-0 pointer-events-none">
            {layout.couples.map((c, i) => {
              const hi = unionHi(c.aId, c.bId)
              const color = hi ? '#FFC857' : '#FF7E6B'
              const dim = lineage && !hi
              const mx = (c.ax + c.bx) / 2
              const my = (c.ay + c.by) / 2
              return (
                <g key={`c${i}`} opacity={dim ? 0.35 : 1}>
                  <line x1={c.ax} y1={c.ay} x2={c.bx} y2={c.by} stroke={color} strokeWidth={hi ? 4 : 2.5} />
                  <circle cx={mx} cy={my} r={11} fill="#fff" stroke={color} strokeWidth={1.5} />
                  <path d={HEART} transform={`translate(${mx - 7},${my - 7}) scale(0.58)`} fill={color} />
                </g>
              )
            })}
            {layout.parents.map((p, i) => {
              const hi = descentHi(p.childId, p.parentIds)
              return <path key={`p${i}`} d={`M ${p.px} ${p.py} V ${p.busY} H ${p.cx} V ${p.cy}`} fill="none" stroke={hi ? '#FFC857' : '#1FB6A6'} strokeWidth={hi ? 4 : 2} strokeOpacity={lineage ? (hi ? 1 : 0.18) : 0.55} />
            })}
          </svg>

          {[...layout.nodes.values()].map((n) => {
            const age = ageOf(n.member)
            const inLineage = lineage?.members.has(n.member.id)
            const isSelected = lineage?.selectedId === n.member.id
            const dimmed = !!lineage && !inLineage
            const label = lineage?.labels.get(n.member.id)
            return (
              <button
                key={n.member.id}
                onClick={(e) => openMenu(n.member, e)}
                style={{ left: n.x, top: n.y, width: NODE_W, height: NODE_H }}
                className={`absolute flex items-center gap-2 rounded-xl border bg-white px-2 shadow-card transition text-left ${
                  isSelected ? 'border-sun ring-2 ring-sun' : inLineage ? 'border-brand ring-1 ring-brand/40' : 'border-black/10'
                } ${dimmed ? 'opacity-30' : 'hover:shadow-soft hover:border-brand/40'}`}
              >
                <Avatar member={n.member} size={42} />
                <span className="min-w-0">
                  <span className="block truncate text-sm font-bold leading-tight">{fullName(n.member)}</span>
                  <span className="block text-[11px] text-ink/45">
                    {label ? <span className="text-brand-700 font-semibold">{label}</span> : <>{age !== null ? `${age}${n.member.is_living ? '' : ' ✝'}` : n.member.is_living ? '' : '✝'}{n.member.birth_date ? ` · ${new Date(n.member.birth_date).getFullYear()}` : ''}</>}
                  </span>
                </span>
              </button>
            )
          })}
        </div>
      </div>

      {/* Lineage bar */}
      {lineage && (
        <div className="absolute z-10 bottom-4 left-1/2 -translate-x-1/2 flex items-center gap-3 rounded-pill bg-white border border-black/10 shadow-soft px-4 py-2">
          <span className="text-sm">
            Lineage of <span className="font-bold">{members.find((m) => m.id === lineageOf)?.first_name}</span>
          </span>
          <button onClick={() => setFull((f) => !f)} className="text-sm font-semibold text-brand-700 hover:underline">
            {full ? 'Show immediate' : 'Show full'}
          </button>
          <button onClick={() => setLineageOf(null)} className="text-sm text-ink/50 hover:text-coral">Clear</button>
        </div>
      )}

      {/* Node menu */}
      {menu && <NodeMenu state={menu} current={current} myUid={myUid} onClose={() => setMenu(null)} onViewLineage={(id) => { setLineageOf(id); setFull(false); setMenu(null) }} nav={nav} />}
    </div>
  )
}

function NodeMenu({
  state, current, myUid, onClose, onViewLineage, nav,
}: {
  state: MenuState
  current: { myRole?: import('../../lib/types').FamilyRole } | undefined
  myUid?: string
  onClose: () => void
  onViewLineage: (id: string) => void
  nav: (to: string) => void
}) {
  const { member } = state
  const role = current?.myRole
  const isRelative = role === 'relative'
  const canEditThis = roleCanEdit(role) || (isRelative && myUid != null && member.linked_user_id === myUid)
  const canSuggest = role === 'contributor'

  // Clamp position into viewport.
  const W = 240, H = 220
  const left = Math.min(state.x, window.innerWidth - W - 12)
  const top = Math.min(state.y, window.innerHeight - H - 12)

  const Item = ({ icon, label, sub, onClick }: { icon: import('../../components/Icon').IconName; label: string; sub?: string; onClick: () => void }) => (
    <button onClick={onClick} className="w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-brand-50">
      <Icon name={icon} className="h-5 w-5 text-brand-700 mt-0.5 shrink-0" />
      <span>
        <span className="block text-sm font-medium">{label}</span>
        {sub && <span className="block text-xs text-ink/45">{sub}</span>}
      </span>
    </button>
  )

  return (
    <div className="fixed inset-0 z-50" onClick={onClose}>
      <div
        className="absolute rounded-2xl bg-white border border-black/10 shadow-soft overflow-hidden"
        style={{ left, top, width: W }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 px-4 py-3 border-b border-black/5">
          <Avatar member={member} size={36} />
          <span className="font-bold truncate">{fullName(member)}</span>
        </div>
        <Item icon="user" label="View profile" onClick={() => { onClose(); nav(`/app/member/${member.id}`) }} />
        {canEditThis ? (
          <Item icon="edit" label={isRelative ? 'Edit my profile' : 'Edit'} onClick={() => { onClose(); nav(`/app/member/${member.id}/edit`) }} />
        ) : canSuggest ? (
          <Item icon="edit" label="Suggest an edit" onClick={() => { onClose(); nav(`/app/member/${member.id}/edit`) }} />
        ) : null}
        <Item icon="link" label="View lineage" sub="Highlight parents, spouse, children…" onClick={() => onViewLineage(member.id)} />
      </div>
    </div>
  )
}
