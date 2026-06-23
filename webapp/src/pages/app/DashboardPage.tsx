import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { upcomingCelebrations } from '../../lib/celebrations'
import { PageHeader, Spinner, StatCard, QuickLink } from '../../components/ui'
import Icon from '../../components/Icon'

export default function DashboardPage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)

  const celebrations = useMemo(() => upcomingCelebrations(members, rels).slice(0, 4), [members, rels])

  if (!current) return <Spinner />

  const living = members.filter((m) => m.is_living).length
  const surnames = new Set(
    members.map((m) => (m.last_name ?? '').trim().toLowerCase()).filter(Boolean),
  ).size
  const withPhotos = members.filter((m) => m.photo_url).length

  const dayLabel = (d: number) => (d === 0 ? 'Today 🎉' : d === 1 ? 'Tomorrow' : `in ${d} days`)

  return (
    <div>
      <PageHeader
        title={current.name}
        subtitle="Your family at a glance"
        action={
          current.subscription_tier === 'premium' ? (
            <span className="inline-flex items-center gap-1.5 rounded-pill bg-sun/20 text-amber-700 px-3 py-1.5 text-sm font-bold">
              <Icon name="crown" className="h-4 w-4" /> Premium
            </span>
          ) : null
        }
      />

      {isLoading ? (
        <Spinner />
      ) : (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard label="People" value={members.length} icon="members" />
            <StatCard label="Living" value={living} icon="user" />
            <StatCard label="Surnames" value={surnames} icon="link" />
            <StatCard label="With photos" value={withPhotos} icon="camera" />
          </div>

          {/* Upcoming celebrations */}
          <div className="flex items-center justify-between mt-10 mb-4">
            <h2 className="text-lg font-bold">Upcoming celebrations</h2>
            <Link to="/app/celebrations" className="text-sm font-semibold text-brand-700 hover:underline">View all</Link>
          </div>
          {celebrations.length === 0 ? (
            <div className="card p-6 text-sm text-ink/55">
              No celebrations coming up. Add birth dates and wedding dates to your members to see them here.
            </div>
          ) : (
            <div className="grid sm:grid-cols-2 gap-3">
              {celebrations.map((c, i) => (
                <Link key={i} to="/app/celebrations" className="card p-4 flex items-center gap-4 hover:shadow-soft transition">
                  <div className="h-11 w-11 rounded-2xl bg-brand-50 grid place-items-center text-xl">{c.kind === 'birthday' ? '🎂' : '💍'}</div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold truncate">{c.title}</div>
                    <div className="text-xs text-ink/55">{c.subtitle}{c.turning ? ` · ${c.kind === 'birthday' ? `turning ${c.turning}` : `${c.turning} yrs`}` : ''}</div>
                  </div>
                  <span className={`text-xs font-semibold ${c.daysUntil <= 7 ? 'text-brand-700' : 'text-ink/40'}`}>{dayLabel(c.daysUntil)}</span>
                </Link>
              ))}
            </div>
          )}

          <h2 className="mt-10 mb-4 text-lg font-bold">Explore</h2>
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <QuickLink to="/app/tree" icon="tree" title="Family tree" body="See your whole family visually." />
            <QuickLink to="/app/map" icon="map" title="Family map" body="Where your family is in the world." />
            <QuickLink to="/app/members" icon="members" title="Members" body="Browse and edit everyone." />
            <QuickLink to="/app/feed" icon="feed" title="Feed" body="Family news and milestones." />
            <QuickLink to="/app/celebrations" icon="gift" title="Celebrations" body="Upcoming birthdays & anniversaries." />
            <QuickLink to="/app/relate" icon="link" title="How related?" body="Find the link between two people." />
            <QuickLink to="/app/insights" icon="chart" title="Family DNA" body="Your family’s DNA in numbers." />
          </div>
        </>
      )}
    </div>
  )
}
