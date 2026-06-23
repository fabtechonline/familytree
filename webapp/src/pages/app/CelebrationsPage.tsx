import { useMemo } from 'react'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { upcomingCelebrations } from '../../lib/celebrations'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'

export default function CelebrationsPage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)

  const items = useMemo(() => upcomingCelebrations(members, rels), [members, rels])

  const label = (days: number) =>
    days === 0 ? 'Today 🎉' : days === 1 ? 'Tomorrow' : `in ${days} days`

  return (
    <div className="max-w-2xl">
      <PageHeader title="Celebrations" subtitle="Upcoming birthdays and anniversaries" />
      {isLoading ? (
        <Spinner />
      ) : items.length === 0 ? (
        <EmptyState icon="gift" title="Nothing coming up" body="Add birth dates and wedding dates to your members to see celebrations here." />
      ) : (
        <div className="space-y-3">
          {items.map((c, i) => (
            <div key={i} className="card p-4 flex items-center gap-4">
              <div className="h-12 w-12 rounded-2xl bg-brand-50 grid place-items-center text-2xl">
                {c.kind === 'birthday' ? '🎂' : '💍'}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-bold truncate">{c.title}</div>
                <div className="text-sm text-ink/55">
                  {c.subtitle}
                  {c.turning ? ` · ${c.kind === 'birthday' ? `turning ${c.turning}` : `${c.turning} years`}` : ''}
                </div>
              </div>
              <div className={`text-sm font-semibold ${c.daysUntil <= 7 ? 'text-brand-700' : 'text-ink/40'}`}>
                {label(c.daysUntil)}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
