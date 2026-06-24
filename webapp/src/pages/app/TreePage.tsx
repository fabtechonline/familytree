import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../auth/AuthProvider'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { computeLayout, NODE_W, NODE_H, type Orientation } from '../../lib/tree-layout'
import { computeLineage, type Lineage } from '../../lib/lineage'
import { fullName, ageOf } from '../../lib/member-utils'
import { canEdit as roleCanEdit } from '../../lib/types'
import { Spinner, EmptyState } from '../../components/ui'
import Avatar from '../../components/Avatar'
import Icon from '../../components/Icon'
import FanChart from '../../components/FanChart'
import type { Member, Relationship } from '../../lib/types'

const HEART =
  'M12 21s-7-4.4-9.5-8.4C1 9.9 2.4 6.5 5.8 6.5c2 0 3.4 1.2 4.2 2.4.8-1.2 2.2-2.4 4.2-2.4 3.4 0 4.8 3.4 3.3 6.1C19 16.6 12 21 12 21z'

type ViewMode = 'tree' | 'wide' | 'hourglass' | 'fan'
interface MenuState { member: Member; x: number; y: number }

/** parent→children and child→parents adjacency from the relationship edges. */
function adjacency(rels: Relationship[]) {
  const children = new Map<string, string[]>()
  const parents = new Map<string, string[]>()
  for (const r of rels) {
    if (r.type !== 'parent') continue
    ;(children.get(r.from_member) ?? children.set(r.from_member, []).get(r.from_member)!).push(r.to_member)
    ;(parents.get(r.to_member) ?? parents.set(r.to_member, []).get(r.to_member)!).push(r.from_member)
  }
  return { children, parents }
}

export default function TreePage() {
  const { current } = useFamily()
  const { session } = useAuth()
  const myUid = session?.user.id
  const nav = useNavigate()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [], isLoading: relLoading } = useRelationships(current?.id)

  const [mode, setMode] = useState<ViewMode>('tree')
  const [focusId, setFocusId] = useState<string | null>(null)
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())
  const [menu, setMenu] = useState<MenuState | null>(null)
  const [lineageOf, setLineageOf] = useState<string | null>(null)
  const [full, setFull] = useState(false)

  const orientation: Orientation = mode === 'wide' ? 'horizontal' : 'vertical'
  const { children, parents } = useMemo(() => adjacency(rels), [rels])
  const partnersOf = useMemo(() => {
    const m = new Map<string, string[]>()
    for (const r of rels) {
      if (r.type === 'parent') continue
      ;(m.get(r.from_member) ?? m.set(r.from_member, []).get(r.from_member)!).push(r.to_member)
      ;(m.get(r.to_member) ?? m.set(r.to_member, []).get(r.to_member)!).push(r.from_member)
    }
    return m
  }, [rels])

  // descendants of a node (for collapse) / a full hourglass set (ancestors + descendants + spouses)
  const descendantsOf = (id: string) => {
    const out = new Set<string>()
    const stack = [...(children.get(id) ?? [])]
    while (stack.length) {
      const c = stack.pop()!
      if (out.has(c)) continue
      out.add(c)
      for (const g of children.get(c) ?? []) stack.push(g)
    }
    return out
  }
  const hourglassSet = (id: string) => {
    const out = new Set<string>([id])
    const up = [...(parents.get(id) ?? [])]
    while (up.length) { const p = up.pop()!; if (!out.has(p)) { out.add(p); for (const x of parents.get(p) ?? []) up.push(x) } }
    for (const d of descendantsOf(id)) out.add(d)
    for (const m of [...out]) for (const s of partnersOf.get(m) ?? []) out.add(s)
    return out
  }

  // default the hourglass focus to "me" (or the first member)
  useEffect(() => {
    if ((mode === 'hourglass' || mode === 'fan') && !focusId && members.length) {
      const mine = members.find((m) => m.linked_user_id === myUid)
      setFocusId(mine?.id ?? members[0].id)
    }
  }, [mode, focusId, members, myUid])

  const { visMembers, visRels, hiddenCounts } = useMemo(() => {
    let base = members
    if (mode === 'hourglass' && focusId) {
      const set = hourglassSet(focusId)
      base = members.filter((m) => set.has(m.id))
    }
    const hidden = new Set<string>()
    const counts = new Map<string, number>()
    for (const id of collapsed) {
      const d = descendantsOf(id)
      if (d.size && base.some((m) => m.id === id)) counts.set(id, d.size)
      for (const x of d) hidden.add(x)
    }
    const vm = base.filter((m) => !hidden.has(m.id))
    const ids = new Set(vm.map((m) => m.id))
    const vr = rels.filter((r) => ids.has(r.from_member) && ids.has(r.to_member))
    return { visMembers: vm, visRels: vr, hiddenCounts: counts }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [members, rels, mode, focusId, collapsed])

  const layout = useMemo(() => computeLayout(visMembers, visRels, orientation), [visMembers, visRels, orientation])

  const lineage: Lineage | null = useMemo(
    () => (lineageOf ? computeLineage(visMembers, visRels, lineageOf, full) : null),
    [visMembers, visRels, lineageOf, full],
  )

  const wrapRef = useRef<HTMLDivElement>(null)
  const [view, setView] = useState({ x: 0, y: 0, scale: 1 })
  const drag = useRef<{ x: number; y: number; vx: number; vy: number; moved: boolean } | null>(null)

  useEffect(() => {
    const el = wrapRef.current
    if (!el || layout.nodes.size === 0) return
    const scale = Math.min(1, Math.min(el.clientWidth / layout.width, el.clientHeight / layout.height) * 0.95)
    setView({ x: (el.clientWidth - layout.width * scale) / 2, y: 24, scale })
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
  const onPointerDown = (e: React.PointerEvent) => { drag.current = { x: e.clientX, y: e.clientY, vx: view.x, vy: view.y, moved: false } }
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current) return
    const dx = e.clientX - drag.current.x
    const dy = e.clientY - drag.current.y
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) drag.current.moved = true
    setView((v) => ({ ...v, x: drag.current!.vx + dx, y: drag.current!.vy + dy }))
  }
  const onPointerUp = () => { drag.current = null }
  const zoom = (factor: number) => setView((v) => ({ ...v, scale: Math.min(2.5, Math.max(0.15, v.scale * factor)) }))

  const openMenu = (member: Member, e: React.MouseEvent) => {
    if (drag.current?.moved) return
    setMenu({ member, x: e.clientX, y: e.clientY })
  }

  if (isLoading || relLoading) return <Spinner />
  if (members.length === 0) {
    return <EmptyState icon="tree" title="Your tree is empty" body="Add members and link relationships to see your family tree." />
  }

  const descentHi = (childId: string, parentIds: string[]) =>
    !!lineage && (lineage.descentChildIds.has(childId) || parentIds.some((p) => lineage.descentParentIds.has(p)))
  const unionHi = (aId: string, bId: string) => !!lineage && (lineage.unionMembers.has(aId) || lineage.unionMembers.has(bId))

  const elbow = (p: { px: number; py: number; bus: number; cx: number; cy: number }) =>
    layout.orientation === 'vertical'
      ? `M ${p.px} ${p.py} V ${p.bus} H ${p.cx} V ${p.cy}`
      : `M ${p.px} ${p.py} H ${p.bus} V ${p.cy} H ${p.cx}`

  const SwitchBtn = ({ m, label, icon }: { m: ViewMode; label: string; icon: import('../../components/Icon').IconName }) => (
    <button
      onClick={() => setMode(m)}
      className={`flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-pill ${mode === m ? 'bg-brand text-white' : 'text-ink/60 hover:bg-brand-50'}`}
    >
      <Icon name={icon} className="h-4 w-4" /> {label}
    </button>
  )

  return (
    <div className="relative h-[calc(100vh-7rem)] rounded-2xl border border-black/5 bg-white overflow-hidden">
      <div className="absolute z-10 top-4 left-4 rounded-pill bg-white/90 backdrop-blur border border-black/5 px-4 py-1.5 shadow-card">
        <h1 className="font-extrabold">{current?.name}</h1>
      </div>

      <div className="absolute z-10 top-4 left-1/2 -translate-x-1/2 flex items-center gap-1 rounded-pill bg-white/95 backdrop-blur border border-black/5 p-1 shadow-card">
        <SwitchBtn m="tree" label="Tree" icon="tree" />
        <SwitchBtn m="wide" label="Wide" icon="arrow" />
        <SwitchBtn m="hourglass" label="Focus" icon="user" />
        <SwitchBtn m="fan" label="Fan" icon="chart" />
      </div>

      <div className="absolute z-10 top-4 right-4 flex flex-col gap-2">
        <button onClick={() => zoom(1.2)} className="h-9 w-9 rounded-lg bg-white border border-black/10 grid place-items-center hover:border-brand/40 text-lg font-bold">+</button>
        <button onClick={() => zoom(1 / 1.2)} className="h-9 w-9 rounded-lg bg-white border border-black/10 grid place-items-center hover:border-brand/40 text-lg font-bold">–</button>
        {collapsed.size > 0 && (
          <button onClick={() => setCollapsed(new Set())} title="Expand all" className="h-9 w-9 rounded-lg bg-white border border-black/10 grid place-items-center hover:border-brand/40"><Icon name="tree" className="h-4 w-4" /></button>
        )}
      </div>

      <div
        ref={wrapRef}
        className="absolute inset-0 cursor-grab active:cursor-grabbing touch-none"
        onWheel={onWheel} onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={onPointerUp} onPointerLeave={onPointerUp}
      >
        <div className="absolute top-0 left-0 origin-top-left" style={{ width: layout.width, height: layout.height, transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})` }}>
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
              return <path key={`p${i}`} d={elbow(p)} fill="none" stroke={hi ? '#FFC857' : '#1FB6A6'} strokeWidth={hi ? 4 : 2} strokeOpacity={lineage ? (hi ? 1 : 0.18) : 0.55} />
            })}
          </svg>

          {[...layout.nodes.values()].map((n) => {
            const age = ageOf(n.member)
            const inLineage = lineage?.members.has(n.member.id)
            const isSelected = lineage?.selectedId === n.member.id || (mode === 'hourglass' && focusId === n.member.id)
            const dimmed = !!lineage && !inLineage
            const label = lineage?.labels.get(n.member.id)
            const hiddenN = hiddenCounts.get(n.member.id)
            return (
              <div key={n.member.id} style={{ left: n.x, top: n.y, width: NODE_W, height: NODE_H }} className="absolute">
                <button
                  onClick={(e) => openMenu(n.member, e)}
                  style={{ width: NODE_W, height: NODE_H }}
                  className={`flex items-center gap-2 rounded-xl border bg-white px-2 shadow-card transition text-left ${
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
                {hiddenN ? (
                  <button
                    onClick={() => setCollapsed((s) => { const n2 = new Set(s); n2.delete(n.member.id); return n2 })}
                    title="Expand branch"
                    className="absolute left-1/2 -translate-x-1/2 top-full mt-1 rounded-pill bg-brand text-white text-[11px] font-bold px-2 py-0.5 shadow-card"
                  >+{hiddenN}</button>
                ) : null}
              </div>
            )
          })}
        </div>
      </div>

      {mode === 'fan' && focusId && (
        <div className="absolute inset-0 z-[5] bg-white">
          <FanChart members={members} rels={rels} focusId={focusId} onSelect={openMenu} />
        </div>
      )}

      {(mode === 'hourglass' || mode === 'fan') && focusId && (
        <div className="absolute z-10 bottom-4 left-1/2 -translate-x-1/2 rounded-pill bg-white border border-black/10 shadow-soft px-4 py-2 text-sm">
          {mode === 'fan' ? 'Ancestors of' : 'Focused on'} <span className="font-bold">{members.find((m) => m.id === focusId)?.first_name}</span> — tap any person → “Focus here”.
        </div>
      )}
      {lineage && (
        <div className="absolute z-10 bottom-4 left-1/2 -translate-x-1/2 flex items-center gap-3 rounded-pill bg-white border border-black/10 shadow-soft px-4 py-2">
          <span className="text-sm">Lineage of <span className="font-bold">{members.find((m) => m.id === lineageOf)?.first_name}</span></span>
          <button onClick={() => setFull((f) => !f)} className="text-sm font-semibold text-brand-700 hover:underline">{full ? 'Show immediate' : 'Show full'}</button>
          <button onClick={() => setLineageOf(null)} className="text-sm text-ink/50 hover:text-coral">Clear</button>
        </div>
      )}

      {menu && (
        <NodeMenu
          state={menu} current={current} myUid={myUid} mode={mode}
          collapsed={collapsed.has(menu.member.id)}
          hasChildren={(children.get(menu.member.id)?.length ?? 0) > 0}
          onClose={() => setMenu(null)}
          onViewLineage={(id) => { setLineageOf(id); setFull(false); setMenu(null) }}
          onFocus={(id) => { setMode('hourglass'); setFocusId(id); setMenu(null) }}
          onToggleCollapse={(id) => { setCollapsed((s) => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n }); setMenu(null) }}
          nav={nav}
        />
      )}
    </div>
  )
}

function NodeMenu({
  state, current, myUid, mode, collapsed, hasChildren, onClose, onViewLineage, onFocus, onToggleCollapse, nav,
}: {
  state: MenuState
  current: { myRole?: import('../../lib/types').FamilyRole } | undefined
  myUid?: string
  mode: ViewMode
  collapsed: boolean
  hasChildren: boolean
  onClose: () => void
  onViewLineage: (id: string) => void
  onFocus: (id: string) => void
  onToggleCollapse: (id: string) => void
  nav: (to: string) => void
}) {
  const { member } = state
  const role = current?.myRole
  const isRelative = role === 'relative'
  const canEditThis = roleCanEdit(role) || (isRelative && myUid != null && member.linked_user_id === myUid)
  const canSuggest = role === 'contributor'

  const W = 250, H = 280
  const left = Math.min(state.x, window.innerWidth - W - 12)
  const top = Math.min(state.y, window.innerHeight - H - 12)

  const Item = ({ icon, label, sub, onClick }: { icon: import('../../components/Icon').IconName; label: string; sub?: string; onClick: () => void }) => (
    <button onClick={onClick} className="w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-brand-50">
      <Icon name={icon} className="h-5 w-5 text-brand-700 mt-0.5 shrink-0" />
      <span><span className="block text-sm font-medium">{label}</span>{sub && <span className="block text-xs text-ink/45">{sub}</span>}</span>
    </button>
  )

  return (
    <div className="fixed inset-0 z-50" onClick={onClose}>
      <div className="absolute rounded-2xl bg-white border border-black/10 shadow-soft overflow-hidden" style={{ left, top, width: W }} onClick={(e) => e.stopPropagation()}>
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
        <Item icon="user" label={mode === 'hourglass' ? 'Focus here' : 'Focus on this person'} sub="Ancestors + descendants only" onClick={() => onFocus(member.id)} />
        <Item icon="link" label="View lineage" sub="Highlight parents, spouse, children…" onClick={() => onViewLineage(member.id)} />
        {hasChildren && (
          <Item icon="chevron" label={collapsed ? 'Expand branch' : 'Collapse branch'} sub="Hide/show this person’s descendants" onClick={() => onToggleCollapse(member.id)} />
        )}
      </div>
    </div>
  )
}
