import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers } from '../../data/queries'
import { fullName } from '../../lib/member-utils'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'
import Avatar from '../../components/Avatar'

export default function TimeMachinePage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)

  const years = useMemo(() => {
    const ys = members
      .map((m) => (m.birth_date ? new Date(m.birth_date).getFullYear() : null))
      .filter((y): y is number => y !== null && !isNaN(y))
    return ys.length ? { min: Math.min(...ys), max: new Date().getFullYear() } : null
  }, [members])

  const [year, setYear] = useState<number | null>(null)
  const activeYear = year ?? years?.max ?? new Date().getFullYear()

  const present = useMemo(
    () =>
      members.filter((m) => {
        if (!m.birth_date) return false
        const b = new Date(m.birth_date).getFullYear()
        if (b > activeYear) return false
        if (m.death_date) {
          const d = new Date(m.death_date).getFullYear()
          if (d < activeYear) return false
        }
        return true
      }),
    [members, activeYear],
  )

  if (isLoading) return <Spinner />
  if (!years) {
    return (
      <div>
        <PageHeader title="Time machine" />
        <EmptyState icon="clock" title="No dates yet" body="Add birth dates to your members to travel through your family’s history." />
      </div>
    )
  }

  const bornThisYear = present.filter((m) => new Date(m.birth_date!).getFullYear() === activeYear)

  return (
    <div>
      <PageHeader title="Time machine" subtitle="Watch your family grow through the years" />
      <div className="card p-6">
        <div className="flex items-baseline justify-between">
          <span className="text-5xl font-extrabold text-brand-700">{activeYear}</span>
          <span className="text-ink/55">{present.length} {present.length === 1 ? 'person' : 'people'} living</span>
        </div>
        <input
          type="range"
          min={years.min}
          max={years.max}
          value={activeYear}
          onChange={(e) => setYear(Number(e.target.value))}
          className="w-full mt-4 accent-brand"
        />
        <div className="flex justify-between text-xs text-ink/40">
          <span>{years.min}</span>
          <span>{years.max}</span>
        </div>
        {bornThisYear.length > 0 && (
          <p className="mt-3 text-sm text-brand-700">
            ✨ {bornThisYear.map((m) => m.first_name).join(', ')} {bornThisYear.length === 1 ? 'was' : 'were'} born this year.
          </p>
        )}
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 mt-6">
        {present.map((m) => (
          <Link key={m.id} to={`/app/member/${m.id}`} className="card p-4 flex items-center gap-3 hover:shadow-soft transition">
            <Avatar member={m} size={40} />
            <div className="min-w-0">
              <div className="font-semibold text-sm truncate">{fullName(m)}</div>
              <div className="text-xs text-ink/45">age {activeYear - new Date(m.birth_date!).getFullYear()}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
