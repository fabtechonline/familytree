import { useMemo, useState } from 'react'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import { shortestPath } from '../../lib/relationships'
import { describeKinship } from '../../lib/kinship'
import { fullName } from '../../lib/member-utils'
import { PageHeader, Spinner } from '../../components/ui'
import Avatar from '../../components/Avatar'

const viaLabel: Record<string, string> = {
  parent: 'is the parent of',
  child: 'is a child of',
  partner: 'is the partner of',
}

export default function RelatePage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)
  const [aId, setAId] = useState('')
  const [bId, setBId] = useState('')

  const byId = useMemo(() => new Map(members.map((m) => [m.id, m])), [members])
  const result = useMemo(() => {
    if (!aId || !bId || aId === bId) return null
    const path = shortestPath(aId, bId, rels)
    if (!path) return { path: null as null, term: '' }
    return { path, term: describeKinship(path) }
  }, [aId, bId, rels])

  if (isLoading) return <Spinner />

  const Select = ({ value, onChange, label }: { value: string; onChange: (v: string) => void; label: string }) => (
    <label className="block flex-1">
      <span className="text-sm font-medium">{label}</span>
      <select className="input mt-1" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Select a person…</option>
        {members.map((m) => <option key={m.id} value={m.id}>{fullName(m)}</option>)}
      </select>
    </label>
  )

  const a = byId.get(aId)
  const b = byId.get(bId)

  return (
    <div className="max-w-2xl">
      <PageHeader title="How are they related?" subtitle="Pick two people to see the connection" />
      <div className="card p-6 flex flex-col sm:flex-row gap-4">
        <Select label="Person A" value={aId} onChange={setAId} />
        <Select label="Person B" value={bId} onChange={setBId} />
      </div>

      {aId && bId && aId === bId && <p className="mt-6 text-ink/60">Pick two different people.</p>}

      {result && a && b && (
        <div className="card p-6 mt-6">
          {result.path === null ? (
            <p className="text-ink/60">No connection found between {a.first_name} and {b.first_name} in the tree yet.</p>
          ) : (
            <>
              <p className="text-lg">
                <span className="font-bold">{b.first_name}</span> is{' '}
                <span className="font-bold text-brand-700">{a.first_name}’s {result.term}</span>.
              </p>
              <div className="mt-5 space-y-2">
                {(() => {
                  let prevId = aId
                  return result.path.map((step, i) => {
                    const person = byId.get(step.id)!
                    const prev = byId.get(prevId)!
                    prevId = step.id
                    return (
                      <div key={i} className="flex items-center gap-3 text-sm">
                        <Avatar member={person} size={32} />
                        <span>
                          <span className="font-medium">{fullName(person)}</span>{' '}
                          <span className="text-ink/50">{viaLabel[step.via]} {prev.first_name}</span>
                        </span>
                      </div>
                    )
                  })
                })()}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}
