import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers } from '../../data/queries'
import { canEdit, canContribute } from '../../lib/types'
import { fullName, ageOf } from '../../lib/member-utils'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'
import Avatar from '../../components/Avatar'
import Icon from '../../components/Icon'

export default function MembersPage() {
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const [q, setQ] = useState('')
  const editable = canEdit(current?.myRole)
  const mayAdd = canContribute(current?.myRole)
  const addLabel = editable ? 'Add member' : 'Suggest a member'

  const filtered = useMemo(() => {
    const t = q.trim().toLowerCase()
    if (!t) return members
    return members.filter((m) =>
      [m.first_name, m.last_name, m.maiden_name, m.birth_place]
        .filter(Boolean)
        .some((s) => s!.toLowerCase().includes(t)),
    )
  }, [members, q])

  return (
    <div>
      <PageHeader
        title="Members"
        subtitle={`${members.length} ${members.length === 1 ? 'person' : 'people'} in ${current?.name ?? 'your family'}`}
        action={
          mayAdd && (
            <Link to="/app/members/new" className="btn-primary">
              <Icon name="plus" className="h-5 w-5" /> {addLabel}
            </Link>
          )
        }
      />

      {members.length > 0 && (
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search by name or birthplace…"
          className="input mb-6 max-w-md"
        />
      )}

      {isLoading ? (
        <Spinner />
      ) : members.length === 0 ? (
        <EmptyState
          icon="members"
          title="No people yet"
          body="Add your first family member to start building the tree."
          action={mayAdd && <Link to="/app/members/new" className="btn-primary">{editable ? 'Add the first member' : 'Suggest a member'}</Link>}
        />
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {filtered.map((m) => {
            const age = ageOf(m)
            return (
              <Link key={m.id} to={`/app/member/${m.id}`} className="card p-5 text-center hover:shadow-soft transition">
                <Avatar member={m} size={72} className="mx-auto" />
                <div className="mt-3 font-bold truncate">{fullName(m)}</div>
                <div className="text-xs text-ink/50 mt-0.5">
                  {age !== null ? `${age} yrs${m.is_living ? '' : ' · ✝'}` : m.is_living ? 'Living' : '✝'}
                </div>
              </Link>
            )
          })}
        </div>
      )}
    </div>
  )
}
