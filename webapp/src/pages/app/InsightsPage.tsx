import { useMemo } from 'react'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { computeFamilyDNA } from '../../lib/family-dna'
import { PageHeader, Spinner } from '../../components/ui'

function Insight({ emoji, label, value }: { emoji: string; label: string; value: string }) {
  return (
    <div className="card p-5 flex flex-col justify-between min-h-[120px]">
      <span className="text-2xl">{emoji}</span>
      <div className="mt-3">
        <div className="text-xl font-extrabold leading-tight">{value}</div>
        <div className="text-sm text-ink/55">{label}</div>
      </div>
    </div>
  )
}

export default function InsightsPage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)

  const s = useMemo(() => computeFamilyDNA(members, rels), [members, rels])

  if (isLoading) return <Spinner />

  const cards: { emoji: string; label: string; value: string }[] = [
    { emoji: '👪', label: 'People in the tree', value: `${s.totalPeople}` },
    { emoji: '🌳', label: 'Generations', value: `${s.generations}` },
  ]
  if (s.commonSurname)
    cards.push({
      emoji: '🔤',
      label: s.commonSurname.includes('&') ? `Top surnames (${s.commonSurnameCount} each)` : `Most common surname (×${s.commonSurnameCount})`,
      value: s.commonSurname,
    })
  if (s.commonFirstName)
    cards.push({
      emoji: '⭐',
      label: s.commonFirstName.includes('&') ? `Top first names (${s.commonFirstNameCount} each)` : `Most common first name (×${s.commonFirstNameCount})`,
      value: s.commonFirstName,
    })
  if (s.averageLifespan != null)
    cards.push({ emoji: '🕰️', label: 'Average lifespan', value: `${s.averageLifespan} yrs` })
  if (s.oldestLivingName)
    cards.push({ emoji: '🎖️', label: 'Oldest living (with a birth date)', value: `${s.oldestLivingName} (${s.oldestLivingAge})` })
  cards.push({ emoji: '👥', label: 'Biggest generation', value: `${s.largestGeneration} people` })
  if (s.averageChildren != null)
    cards.push({ emoji: '🍼', label: 'Avg. children per parent', value: s.averageChildren.toFixed(1) })
  cards.push({ emoji: '🗺️', label: 'Birthplaces', value: `${s.birthplaceCount}` })

  return (
    <div>
      <PageHeader title="Family DNA" subtitle="Playful facts about your family" />
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        {cards.map((c) => (
          <Insight key={c.label} emoji={c.emoji} label={c.label} value={c.value} />
        ))}
      </div>
    </div>
  )
}
