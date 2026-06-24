import { useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships, useMemberMedia } from '../../data/queries'
import { addMemory, deleteMemory } from '../../data/mutations'
import { canEdit } from '../../lib/types'
import { fullName, ageOf, formatDate } from '../../lib/member-utils'
import { getRelations } from '../../lib/relationships'
import { Spinner } from '../../components/ui'
import Avatar from '../../components/Avatar'
import Icon from '../../components/Icon'
import type { Member } from '../../lib/types'

function RelationGroup({ label, people }: { label: string; people: Member[] }) {
  if (people.length === 0) return null
  return (
    <div>
      <h3 className="text-sm font-semibold text-ink/50 mb-2">{label}</h3>
      <div className="flex flex-wrap gap-3">
        {people.map((p) => (
          <Link key={p.id} to={`/app/member/${p.id}`} className="flex items-center gap-2 rounded-pill border border-black/10 bg-white pl-1 pr-4 py-1 hover:border-brand/40">
            <Avatar member={p} size={32} />
            <span className="text-sm font-medium">{fullName(p)}</span>
          </Link>
        ))}
      </div>
    </div>
  )
}

export default function MemberProfilePage() {
  const { id } = useParams()
  const { session } = useAuth()
  const myUid = session?.user.id
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)

  if (isLoading) return <Spinner />
  const member = members.find((m) => m.id === id)
  if (!member) {
    return (
      <div className="card p-12 text-center">
        <p className="text-ink/60">This person could not be found.</p>
        <Link to="/app/members" className="btn-ghost mt-4">Back to members</Link>
      </div>
    )
  }

  const age = ageOf(member)
  const relations = getRelations(member.id, members, rels)
  const role = current?.myRole
  const canEditThis = canEdit(role) || (role === 'relative' && member.linked_user_id === myUid)
  const canSuggest = role === 'contributor'
  const showEdit = canEditThis || canSuggest

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <Link to="/app/members" className="text-sm text-ink/60 hover:text-brand-700">← All members</Link>
        {showEdit && (
          <Link to={`/app/member/${member.id}/edit`} className="btn-ghost h-10">
            <Icon name="edit" className="h-4 w-4" /> {canEditThis ? 'Edit' : 'Suggest an edit'}
          </Link>
        )}
      </div>

      <div className="card p-8">
        <div className="flex flex-col sm:flex-row gap-6 items-center sm:items-start">
          <Avatar member={member} size={120} />
          <div className="text-center sm:text-left">
            <h1 className="text-3xl font-extrabold tracking-tight">{fullName(member)}</h1>
            {member.maiden_name && <p className="text-ink/50">née {member.maiden_name}</p>}
            <div className="mt-2 flex flex-wrap gap-2 justify-center sm:justify-start text-sm">
              {!member.is_living && <span className="rounded-pill bg-black/5 px-3 py-1">In memoriam</span>}
              {member.gender && <span className="rounded-pill bg-brand-50 text-brand-700 px-3 py-1 capitalize">{member.gender}</span>}
              {age !== null && <span className="rounded-pill bg-brand-50 text-brand-700 px-3 py-1">{age} years{member.is_living ? '' : ' (at passing)'}</span>}
            </div>
          </div>
        </div>

        <div className="mt-8 grid sm:grid-cols-2 gap-4 text-sm">
          {member.birth_date && <Detail label="Born" value={`${formatDate(member.birth_date)}${member.birth_place ? ` · ${member.birth_place}` : ''}`} />}
          {member.death_date && <Detail label="Passed away" value={formatDate(member.death_date)} />}
          {!member.birth_date && member.birth_place && <Detail label="Birthplace" value={member.birth_place} />}
          {member.occupation && <Detail label="Occupation" value={member.occupation} />}
          {member.phone && <Detail label="Phone" value={member.phone} />}
          {member.address && <Detail label="Address" value={member.address} />}
        </div>

        {member.bio && (
          <div className="mt-6">
            <h3 className="text-sm font-semibold text-ink/50 mb-1">About</h3>
            <p className="text-ink/80 leading-relaxed whitespace-pre-wrap">{member.bio}</p>
          </div>
        )}
      </div>

      <div className="card p-8 mt-6 space-y-6">
        <h2 className="text-lg font-bold">Relationships</h2>
        <RelationGroup label="Parents" people={relations.parents} />
        <RelationGroup label="Partners" people={relations.partners} />
        <RelationGroup label="Children" people={relations.children} />
        <RelationGroup label="Siblings" people={relations.siblings} />
        {relations.parents.length + relations.partners.length + relations.children.length + relations.siblings.length === 0 && (
          <p className="text-sm text-ink/50">No relationships recorded yet.{canEditThis ? ' Add them from the edit screen.' : ''}</p>
        )}
      </div>

      <MemoriesSection memberId={member.id} familyId={current!.id} canAdd={canEditThis} uid={myUid} />
      <AuditFooter memberId={member.id} />
    </div>
  )
}

function AuditFooter({ memberId }: { memberId: string }) {
  const { data } = useQuery({
    queryKey: ['member-audit', memberId],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('member_audit', { p_member: memberId })
      if (error) throw error
      return (Array.isArray(data) ? data[0] : data) as
        | { created_by_name: string; created_at: string; updated_by_name: string | null; updated_at: string }
        | null
    },
  })
  if (!data) return null
  return (
    <p className="mt-4 text-center text-xs text-ink/40">
      Added by {data.created_by_name} · {formatDate(data.created_at)}
      {data.updated_by_name && data.updated_at !== data.created_at && (
        <> · Last updated by {data.updated_by_name} · {formatDate(data.updated_at)}</>
      )}
    </p>
  )
}

function MemoriesSection({
  memberId, familyId, canAdd, uid,
}: { memberId: string; familyId: string; canAdd: boolean; uid?: string }) {
  const qc = useQueryClient()
  const { data: memories = [] } = useMemberMedia(memberId)
  const fileRef = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = () => qc.invalidateQueries({ queryKey: ['member-media', memberId] })

  const onPick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setBusy(true)
    setError(null)
    try {
      await addMemory({ familyId, memberId, file })
      refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed')
    } finally {
      setBusy(false)
      if (fileRef.current) fileRef.current.value = ''
    }
  }

  const remove = async (id: string) => {
    if (!confirm('Remove this photo?')) return
    await deleteMemory(id)
    refresh()
  }

  if (memories.length === 0 && !canAdd) return null

  return (
    <div className="card p-8 mt-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-bold">Memories</h2>
        {canAdd && (
          <button onClick={() => fileRef.current?.click()} disabled={busy} className="btn-ghost h-10">
            <Icon name="camera" className="h-4 w-4" /> {busy ? 'Uploading…' : 'Add photo'}
          </button>
        )}
        <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPick} />
      </div>
      {error && <p className="text-sm text-coral mb-3">{error}</p>}
      {memories.length === 0 ? (
        <p className="text-sm text-ink/50">No photos yet. {canAdd ? 'Add a treasured family photo.' : ''}</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          {memories.map((m) => (
            <div key={m.id} className="relative group">
              <img src={m.media_url} alt={m.caption ?? ''} className="w-full aspect-square object-cover rounded-xl" />
              {(canAdd || m.uploaded_by === uid) && (
                <button
                  onClick={() => remove(m.id)}
                  className="absolute top-1.5 right-1.5 h-7 w-7 rounded-full bg-black/55 text-white grid place-items-center opacity-0 group-hover:opacity-100 transition"
                  title="Remove"
                >
                  <Icon name="trash" className="h-4 w-4" />
                </button>
              )}
              {m.caption && <div className="mt-1 text-xs text-ink/55 truncate">{m.caption}</div>}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-canvas px-4 py-3">
      <div className="text-xs text-ink/45">{label}</div>
      <div className="font-medium mt-0.5">{value}</div>
    </div>
  )
}
