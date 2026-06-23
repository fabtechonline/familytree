import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { fullName, initials, avatarColor } from '../../lib/member-utils'
import { memberImageUrl } from '../../lib/avatar'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'
import type { Member, Relationship } from '../../lib/types'

type LatLng = [number, number]

// Spread markers that share the same coordinate into a small ring so they're
// individually visible/clickable (e.g. several relatives born in one town).
function spread(points: { id: string; lat: number; lng: number }[]): Map<string, LatLng> {
  const groups = new Map<string, typeof points>()
  for (const p of points) {
    const k = `${p.lat.toFixed(4)},${p.lng.toFixed(4)}`
    const g = groups.get(k) ?? []
    g.push(p)
    groups.set(k, g)
  }
  const out = new Map<string, LatLng>()
  for (const grp of groups.values()) {
    if (grp.length === 1) {
      out.set(grp[0].id, [grp[0].lat, grp[0].lng])
      continue
    }
    const R = 0.02
    grp.forEach((p, i) => {
      const a = (i / grp.length) * 2 * Math.PI
      out.set(p.id, [p.lat + R * Math.sin(a), p.lng + R * Math.cos(a)])
    })
  }
  return out
}

function avatarIcon(m: Member, ringColor: string): L.DivIcon {
  const img = memberImageUrl(m, 76)
  const inner = img
    ? `<img src="${img}" style="width:100%;height:100%;object-fit:cover;border-radius:9999px"/>`
    : `<div style="width:100%;height:100%;border-radius:9999px;display:grid;place-items:center;background:${avatarColor(m.id)};color:#fff;font-weight:700;font-size:13px">${initials(m)}</div>`
  return L.divIcon({
    className: 'riza-pin',
    html: `<div style="width:38px;height:38px;border-radius:9999px;border:3px solid ${ringColor};box-shadow:0 1px 4px rgba(0,0,0,.3);overflow:hidden;background:#fff">${inner}</div>`,
    iconSize: [38, 38],
    iconAnchor: [19, 19],
    popupAnchor: [0, -19],
  })
}

function FitBounds({ points }: { points: LatLng[] }) {
  const map = useMap()
  useMemo(() => {
    if (points.length === 0) return
    if (points.length === 1) {
      map.setView(points[0], 6)
    } else {
      map.fitBounds(L.latLngBounds(points), { padding: [60, 60] })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [points.length])
  return null
}

function MemberPopup({ m, place }: { m: Member; place?: string | null }) {
  return (
    <div style={{ minWidth: 160 }}>
      <div style={{ fontWeight: 700, fontSize: 14 }}>{fullName(m)}</div>
      {place && <div style={{ color: '#6b7280', fontSize: 12, marginTop: 2 }}>{place}</div>}
      <Link to={`/app/member/${m.id}`} style={{ color: '#149286', fontWeight: 600, fontSize: 12 }}>
        View profile →
      </Link>
    </div>
  )
}

const PARENT_COLOR = '#1FB6A6'
const SPOUSE_COLOR = '#FF7E6B'
const MIGRATION_COLOR = '#FFC857'

export default function MapPage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [], isLoading: relLoading } = useRelationships(current?.id)

  const [showHomes, setShowHomes] = useState(true)
  const [showBirth, setShowBirth] = useState(true)
  const [showMigration, setShowMigration] = useState(true)
  const [showWeb, setShowWeb] = useState(true)

  const data = useMemo(() => {
    const homePts = members
      .filter((m) => m.home_lat != null && m.home_lng != null)
      .map((m) => ({ id: m.id, lat: m.home_lat!, lng: m.home_lng! }))
    const birthPts = members
      .filter((m) => m.birth_lat != null && m.birth_lng != null)
      .map((m) => ({ id: m.id, lat: m.birth_lat!, lng: m.birth_lng! }))
    const homePos = spread(homePts)
    const birthPos = spread(birthPts)
    const byId = new Map(members.map((m) => [m.id, m]))
    const primary = (id: string) => homePos.get(id) ?? birthPos.get(id)

    const all: LatLng[] = [...homePos.values(), ...birthPos.values()]
    const placeKeys = new Set(all.map((p) => `${p[0].toFixed(2)},${p[1].toFixed(2)}`))
    const mapped = members.filter((m) => primary(m.id)).length
    const needLocation = members.filter((m) => !primary(m.id))

    // Family web edges between primary positions of related members.
    const webEdges: { a: LatLng; b: LatLng; color: string }[] = []
    for (const r of rels as Relationship[]) {
      const a = primary(r.from_member)
      const b = primary(r.to_member)
      if (!a || !b) continue
      webEdges.push({ a, b, color: r.type === 'parent' ? PARENT_COLOR : SPOUSE_COLOR })
    }
    // Migration arcs (birth → home) for members with both.
    const migration: { a: LatLng; b: LatLng; id: string }[] = []
    for (const m of members) {
      const h = homePos.get(m.id)
      const bp = birthPos.get(m.id)
      if (h && bp) migration.push({ a: bp, b: h, id: m.id })
    }

    return { homePos, birthPos, byId, all, placeKeys, mapped, needLocation, webEdges, migration }
  }, [members, rels])

  if (isLoading || relLoading) return <Spinner />

  if (data.all.length === 0) {
    return (
      <div>
        <PageHeader title="Family map" />
        <EmptyState
          icon="map"
          title="No locations yet"
          body="Add an address or birthplace to your members and they’ll appear on the map."
        />
      </div>
    )
  }

  const Toggle = ({ on, set, label, color }: { on: boolean; set: (v: boolean) => void; label: string; color: string }) => (
    <button
      onClick={() => set(!on)}
      className={`flex items-center gap-2 rounded-pill border px-3 py-1.5 text-sm ${on ? 'bg-white border-black/15' : 'bg-black/5 border-transparent text-ink/40'}`}
    >
      <span className="h-3 w-3 rounded-full" style={{ background: on ? color : '#bbb' }} />
      {label}
    </button>
  )

  return (
    <div>
      <PageHeader
        title="Family map"
        subtitle={`${data.mapped} mapped · ${data.placeKeys.size} places${data.needLocation.length ? ` · ${data.needLocation.length} need a location` : ''}`}
      />

      <div className="flex flex-wrap gap-2 mb-4">
        <Toggle on={showHomes} set={setShowHomes} label="Homes" color={PARENT_COLOR} />
        <Toggle on={showBirth} set={setShowBirth} label="Birthplaces" color={MIGRATION_COLOR} />
        <Toggle on={showMigration} set={setShowMigration} label="Migration" color={MIGRATION_COLOR} />
        <Toggle on={showWeb} set={setShowWeb} label="Family web" color={SPOUSE_COLOR} />
      </div>

      <div className="rounded-2xl overflow-hidden border border-black/10" style={{ height: 'calc(100vh - 16rem)' }}>
        <MapContainer center={[20, 0]} zoom={2} style={{ height: '100%', width: '100%' }} scrollWheelZoom>
          <TileLayer
            attribution='&copy; OpenStreetMap'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <FitBounds points={data.all} />

          {showWeb &&
            data.webEdges.map((e, i) => (
              <Polyline key={`w${i}`} positions={[e.a, e.b]} pathOptions={{ color: e.color, weight: 2, opacity: 0.5 }} />
            ))}

          {showMigration &&
            data.migration.map((e) => (
              <Polyline key={`m${e.id}`} positions={[e.a, e.b]} pathOptions={{ color: MIGRATION_COLOR, weight: 2, dashArray: '6 6' }} />
            ))}

          {showHomes &&
            [...data.homePos.entries()].map(([id, pos]) => {
              const m = data.byId.get(id)!
              return (
                <Marker key={`h${id}`} position={pos} icon={avatarIcon(m, PARENT_COLOR)}>
                  <Popup><MemberPopup m={m} place={m.address} /></Popup>
                </Marker>
              )
            })}

          {showBirth &&
            [...data.birthPos.entries()].map(([id, pos]) => {
              const m = data.byId.get(id)!
              return (
                <Marker key={`b${id}`} position={pos} icon={avatarIcon(m, MIGRATION_COLOR)}>
                  <Popup><MemberPopup m={m} place={`Born in ${m.birth_place}`} /></Popup>
                </Marker>
              )
            })}
        </MapContainer>
      </div>

      {data.needLocation.length > 0 && (
        <div className="card p-5 mt-4">
          <h3 className="font-bold mb-2">Need a location ({data.needLocation.length})</h3>
          <p className="text-sm text-ink/55 mb-3">Add an address or birthplace to place these people on the map.</p>
          <div className="flex flex-wrap gap-2">
            {data.needLocation.map((m) => (
              <Link key={m.id} to={`/app/member/${m.id}/edit`} className="rounded-pill border border-black/10 px-3 py-1.5 text-sm hover:border-brand/40">
                {fullName(m)}
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
