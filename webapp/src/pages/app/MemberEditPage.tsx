import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../auth/AuthProvider'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers, useRelationships } from '../../data/queries'
import {
  createMember, updateMember, deleteMember,
  addRelationship, deleteRelationship, linkSiblingByParents, submitSuggestion,
  type MemberInput,
} from '../../data/mutations'
import { uploadMemberPhoto } from '../../lib/upload'
import { geocode } from '../../lib/geocode'
import { fullName } from '../../lib/member-utils'
import { canEdit as roleCanEdit } from '../../lib/types'
import {
  type LinkKind, linkLabel, impliedGender, categoryOf, forCategoryGender, forGender,
} from '../../lib/link-kinds'
import { PageHeader, Spinner } from '../../components/ui'
import Avatar from '../../components/Avatar'
import AvatarBuilder from '../../components/AvatarBuilder'
import Icon from '../../components/Icon'
import type { Member, Relationship } from '../../lib/types'

interface AnchorOption {
  key: string
  label: string
  memberIds: string[]
  isCouple: boolean
}

type Form = {
  first_name: string; last_name: string; maiden_name: string; gender: string
  birth_date: string; death_date: string; birth_place: string; bio: string; is_living: boolean
  phone: string; address: string; occupation: string
}
const EMPTY: Form = {
  first_name: '', last_name: '', maiden_name: '', gender: '',
  birth_date: '', death_date: '', birth_place: '', bio: '', is_living: true,
  phone: '', address: '', occupation: '',
}

function buildAnchors(anchors: Member[], rels: Relationship[]): AnchorOption[] {
  const byId = new Map(anchors.map((m) => [m.id, m]))
  const options: AnchorOption[] = anchors.map((m) => ({
    key: m.id, label: fullName(m), memberIds: [m.id], isCouple: false,
  }))
  const seen = new Set<string>()
  for (const r of rels) {
    if (r.type !== 'spouse' && r.type !== 'partner') continue
    const a = byId.get(r.from_member)
    const b = byId.get(r.to_member)
    if (!a || !b) continue
    const pairKey = a.id < b.id ? `${a.id}+${b.id}` : `${b.id}+${a.id}`
    if (seen.has(pairKey)) continue
    seen.add(pairKey)
    options.push({
      key: `couple:${pairKey}`,
      label: `${a.first_name} & ${fullName(b)}`,
      memberIds: [a.id, b.id],
      isCouple: true,
    })
  }
  return options
}

export default function MemberEditPage() {
  const { id } = useParams()
  const isNew = !id
  const nav = useNavigate()
  const qc = useQueryClient()
  const { session } = useAuth()
  const myUid = session?.user.id
  const { current } = useFamily()
  const { data: members = [], isLoading } = useMembers(current?.id)
  const { data: rels = [] } = useRelationships(current?.id)

  const existing = members.find((m) => m.id === id)
  const role = current?.myRole
  const canEdit = roleCanEdit(role)
  const canSelfEdit = !isNew && role === 'relative' && existing?.linked_user_id != null && existing.linked_user_id === myUid
  const canSaveDirect = canEdit || canSelfEdit
  const canSuggest = role === 'contributor'

  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [sent, setSent] = useState(false)

  // Photo (deferred upload — works for add and edit, like mobile)
  const [pickedFile, setPickedFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  // Relationship picker
  const [linkKind, setLinkKind] = useState<LinkKind>('sonOf')
  const [anchorKey, setAnchorKey] = useState<string>('')

  const [avatarOpen, setAvatarOpen] = useState(false)
  const isPremium = current?.subscription_tier === 'premium'

  const hydrated = useRef(false)
  useEffect(() => {
    if (!isNew && existing && !hydrated.current) {
      hydrated.current = true
      setForm({
        first_name: existing.first_name ?? '', last_name: existing.last_name ?? '',
        maiden_name: existing.maiden_name ?? '', gender: existing.gender ?? '',
        birth_date: existing.birth_date ?? '', death_date: existing.death_date ?? '',
        birth_place: existing.birth_place ?? '', bio: existing.bio ?? '',
        is_living: existing.is_living ?? true,
        phone: existing.phone ?? '', address: existing.address ?? '',
        occupation: existing.occupation ?? '',
      })
      if (existing.gender === 'male' || existing.gender === 'female') {
        setLinkKind(forCategoryGender('child', existing.gender === 'male'))
      }
    }
  }, [isNew, existing])

  const anchorOptions = useMemo(
    () => buildAnchors(members.filter((m) => m.id !== id), rels),
    [members, rels, id],
  )
  useEffect(() => {
    if (!anchorKey && anchorOptions.length) setAnchorKey(anchorOptions[0].key)
  }, [anchorOptions, anchorKey])

  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }))
  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['members', current?.id] })
    qc.invalidateQueries({ queryKey: ['relationships', current?.id] })
  }

  const onPickFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    if (!f) return
    setPickedFile(f)
    setPreview(URL.createObjectURL(f))
  }

  const setGender = (g: string) => {
    setForm((f) => ({ ...f, gender: f.gender === g ? '' : g }))
    if (g && linkKind !== 'none') setLinkKind((k) => forCategoryGender(categoryOf(k), g === 'male'))
  }
  const onKindChange = (k: LinkKind) => {
    setLinkKind(k)
    const g = impliedGender(k)
    if (g) setForm((f) => ({ ...f, gender: g }))
  }

  // Geocode home/birthplace (best effort) and store coords for the Family Map.
  // Only geocodes when the text is new/changed; never blocks the save on failure.
  const geocodeIfNeeded = async (memberId: string) => {
    const patch: Record<string, number> = {}
    const addr = form.address.trim()
    const birth = form.birth_place.trim()
    if (addr && (isNew || addr !== (existing?.address ?? ''))) {
      const g = await geocode(addr)
      if (g) { patch.home_lat = g.lat; patch.home_lng = g.lng }
    }
    if (birth && (isNew || birth !== (existing?.birth_place ?? ''))) {
      const g = await geocode(birth)
      if (g) { patch.birth_lat = g.lat; patch.birth_lng = g.lng }
    }
    if (Object.keys(patch).length) await updateMember(memberId, patch as Partial<MemberInput>)
  }

  const applyLink = async (familyId: string, memberId: string) => {
    const opt = anchorOptions.find((o) => o.key === anchorKey)
    if (!opt || linkKind === 'none') return
    const ids = opt.memberIds
    const cat = categoryOf(linkKind)
    if (cat === 'spouse') {
      await addRelationship({ family_id: familyId, from_member: ids[0], to_member: memberId, type: 'spouse' })
    } else if (cat === 'parent') {
      for (const childId of ids) await addRelationship({ family_id: familyId, from_member: memberId, to_member: childId, type: 'parent' })
    } else if (cat === 'child') {
      for (const parentId of ids) await addRelationship({ family_id: familyId, from_member: parentId, to_member: memberId, type: 'parent' })
    } else if (cat === 'sibling') {
      await linkSiblingByParents({ family_id: familyId, newMemberId: memberId, siblingOfId: ids[0] })
    }
  }

  const payload = (): MemberInput => ({
    family_id: current!.id,
    first_name: form.first_name.trim(),
    last_name: form.last_name.trim() || null,
    maiden_name: form.maiden_name.trim() || null,
    gender: form.gender || null,
    birth_date: form.birth_date || null,
    death_date: form.is_living ? null : form.death_date || null,
    is_living: form.is_living,
    birth_place: form.birth_place.trim() || null,
    bio: form.bio.trim() || null,
    phone: form.phone.trim() || null,
    address: form.address.trim() || null,
    occupation: form.occupation.trim() || null,
  })

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!current || !form.first_name.trim()) { setError('First name is required.'); return }
    setSaving(true); setError(null)
    try {
      if (canSuggest) {
        await submitSuggestion({
          family_id: current.id,
          kind: isNew ? 'add_member' : 'edit_member',
          target_member_id: isNew ? undefined : id,
          payload: payload() as Record<string, unknown>,
        })
        setSent(true)
        return
      }
      if (isNew) {
        const created = await createMember(payload())
        if (pickedFile) {
          const url = await uploadMemberPhoto({ familyId: current.id, memberId: created.id, folder: 'avatar', file: pickedFile })
          await updateMember(created.id, { ...payload(), photo_url: url })
        }
        await applyLink(current.id, created.id)
        await geocodeIfNeeded(created.id)
        refresh()
        nav(`/app/member/${created.id}`)
      } else {
        let patch: Partial<MemberInput> = payload()
        if (pickedFile) {
          const url = await uploadMemberPhoto({ familyId: current.id, memberId: id!, folder: 'avatar', file: pickedFile })
          patch = { ...patch, photo_url: url }
        }
        await updateMember(id!, patch)
        await geocodeIfNeeded(id!)
        refresh()
        nav(`/app/member/${id}`)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save')
    } finally {
      setSaving(false)
    }
  }

  const addRelationshipNow = async () => {
    if (!current || isNew) return
    setSaving(true); setError(null)
    try {
      await applyLink(current.id, id!)
      refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not add relationship')
    } finally {
      setSaving(false)
    }
  }

  const remove = async () => {
    if (!id || !confirm('Delete this member? This also removes their relationships.')) return
    await deleteMember(id)
    refresh()
    nav('/app/members')
  }

  if (!isNew && isLoading) return <Spinner />

  if (sent) {
    return (
      <div className="max-w-lg">
        <div className="card p-8 text-center">
          <div className="mx-auto h-14 w-14 rounded-2xl bg-brand-50 text-brand-700 grid place-items-center"><Icon name="check" className="h-7 w-7" /></div>
          <h2 className="mt-4 text-xl font-bold">Sent for approval</h2>
          <p className="mt-2 text-ink/60">Your suggestion was sent to the family admins. It’ll appear once approved.</p>
          <Link to="/app/members" className="btn-primary mt-6">Back to members</Link>
        </div>
      </div>
    )
  }

  const title = canSelfEdit ? 'Edit my profile'
    : canEdit ? (isNew ? 'Add member' : `Edit ${fullName(form)}`)
    : (isNew ? 'Suggest a member' : 'Suggest changes')

  const visibleKinds = forGender(form.gender)
  const selectedAnchor = anchorOptions.find((o) => o.key === anchorKey)
  const photoSrc = preview ?? (!isNew ? existing?.photo_url : null)

  return (
    <div className="max-w-3xl">
      <Link to={isNew ? '/app/members' : `/app/member/${id}`} className="text-sm text-ink/60 hover:text-brand-700">
        ← {isNew ? 'All members' : 'Back to profile'}
      </Link>
      <PageHeader
        title={title}
        action={!isNew && canEdit ? <button onClick={remove} className="text-sm text-coral hover:underline">Delete</button> : undefined}
      />

      {/* Role banners */}
      {canSuggest ? (
        <div className="rounded-xl bg-brand-50 text-brand-800 px-4 py-3 mb-5 text-sm flex gap-2">
          <Icon name="inbox" className="h-5 w-5 shrink-0" /> Your changes will be sent to a family admin for approval.
        </div>
      ) : !canSaveDirect ? (
        <div className="rounded-xl bg-black/5 text-ink/60 px-4 py-3 mb-5 text-sm flex gap-2">
          <Icon name="shield" className="h-5 w-5 shrink-0" /> You have view-only access to this family.
        </div>
      ) : null}

      <form onSubmit={save} className="card p-6 space-y-5">
        {/* Photo header */}
        {canSaveDirect && (
          <div className="flex flex-col items-center">
            <button type="button" onClick={() => fileRef.current?.click()} className="relative">
              {photoSrc ? (
                <img src={photoSrc} alt="" className="h-28 w-28 rounded-full object-cover" />
              ) : (
                <div className="h-28 w-28 rounded-full bg-brand-50 grid place-items-center text-brand-700">
                  <Icon name="camera" className="h-8 w-8" />
                </div>
              )}
              <span className="absolute right-0 bottom-0 h-8 w-8 rounded-full bg-brand text-white grid place-items-center border-2 border-white">
                <Icon name="edit" className="h-4 w-4" />
              </span>
            </button>
            <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPickFile} />
            <span className="mt-2 text-xs text-ink/45">Tap to add a photo</span>
            {!isNew && existing && (
              <button type="button" onClick={() => setAvatarOpen(true)} className="btn-ghost h-9 mt-3 text-sm">
                <Icon name="user" className="h-4 w-4" /> {existing.avatar_config ? 'Edit' : 'Create'} illustrated avatar
              </button>
            )}
          </div>
        )}

        {avatarOpen && existing && (
          <AvatarBuilder member={existing} familyId={current!.id} isPremium={isPremium} onClose={() => setAvatarOpen(false)} />
        )}

        <div className="grid sm:grid-cols-2 gap-4">
          <Field label="First name *"><input required className="input" value={form.first_name} onChange={(e) => set('first_name', e.target.value)} /></Field>
          <Field label="Last name"><input className="input" value={form.last_name} onChange={(e) => set('last_name', e.target.value)} /></Field>
          <Field label="Maiden name"><input className="input" value={form.maiden_name} onChange={(e) => set('maiden_name', e.target.value)} /></Field>
          <Field label="Birthplace"><input className="input" value={form.birth_place} onChange={(e) => set('birth_place', e.target.value)} /></Field>
          <Field label="Occupation"><input className="input" value={form.occupation} onChange={(e) => set('occupation', e.target.value)} /></Field>
          <Field label="Phone"><input type="tel" className="input" value={form.phone} onChange={(e) => set('phone', e.target.value)} /></Field>
        </div>

        <Field label="Address"><textarea rows={2} className="input !h-auto py-3" value={form.address} onChange={(e) => set('address', e.target.value)} /></Field>

        {/* Gender chips */}
        <div>
          <span className="text-sm font-medium">Gender</span>
          <div className="mt-2 flex gap-2">
            {[['male', 'Male'], ['female', 'Female'], ['other', 'Other']].map(([v, label]) => (
              <button type="button" key={v} onClick={() => setGender(v)}
                className={`rounded-pill px-4 py-1.5 text-sm border ${form.gender === v ? 'bg-brand text-white border-brand' : 'border-black/10 hover:border-brand/40'}`}>
                {label}
              </button>
            ))}
          </div>
        </div>

        {/* Living + dates */}
        <label className="flex items-center gap-3 text-sm">
          <input type="checkbox" className="h-5 w-5 rounded accent-brand" checked={form.is_living} onChange={(e) => set('is_living', e.target.checked)} /> Living
        </label>
        <div className="grid sm:grid-cols-2 gap-4">
          <DateField label="Date of birth" value={form.birth_date} onChange={(v) => set('birth_date', v)} />
          {!form.is_living && <DateField label="Date of passing" value={form.death_date} onChange={(v) => set('death_date', v)} />}
        </div>

        <Field label="Bio / notes"><textarea rows={4} className="input !h-auto py-3" value={form.bio} onChange={(e) => set('bio', e.target.value)} /></Field>

        {error && <p className="text-sm text-coral">{error}</p>}

        {(canSaveDirect || canSuggest) && (
          <button type="submit" disabled={saving} className="btn-primary">
            {saving ? 'Saving…' : canSaveDirect ? (canEdit && isNew ? 'Add member' : 'Save changes') : 'Send suggestion'}
          </button>
        )}
      </form>

      {/* Existing relationships (edit + canEdit) */}
      {!isNew && canEdit && existing && (
        <ExistingRelationships member={existing} members={members} rels={rels} onChange={refresh} />
      )}

      {/* Relationship picker */}
      {canEdit && anchorOptions.length > 0 && (
        <div className="card p-6 mt-6">
          <h2 className="font-bold">{isNew ? 'How are they related?' : 'Add a relationship'}</h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {visibleKinds.map((k) => (
              <button type="button" key={k} onClick={() => onKindChange(k)}
                className={`rounded-pill px-3 py-1.5 text-sm border ${linkKind === k ? 'bg-brand text-white border-brand' : 'border-black/10 hover:border-brand/40'}`}>
                {linkLabel[k]}
              </button>
            ))}
          </div>
          {linkKind !== 'none' && selectedAnchor && (
            <>
              <p className="mt-3 text-sm text-ink/55">
                This person is the <span className="font-medium">{linkLabel[linkKind].toLowerCase()}</span>{' '}
                {selectedAnchor.label.split(' ')[0]}{selectedAnchor.isCouple ? ' & partner' : ''}.
              </p>
              <label className="block mt-3">
                <span className="text-sm font-medium">Related member</span>
                <select className="input mt-1" value={anchorKey} onChange={(e) => setAnchorKey(e.target.value)}>
                  {anchorOptions.map((o) => (
                    <option key={o.key} value={o.key}>{o.isCouple ? '❤ ' : ''}{o.label}</option>
                  ))}
                </select>
              </label>
              {!isNew && (
                <button type="button" onClick={addRelationshipNow} disabled={saving} className="btn-ghost mt-4">
                  <Icon name="link" className="h-4 w-4" /> Add relationship
                </button>
              )}
              {isNew && <p className="mt-3 text-xs text-ink/45">This link is created when you add the member.</p>}
            </>
          )}
        </div>
      )}
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="text-sm font-medium">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  )
}

function DateField({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <label className="block">
      <span className="text-sm font-medium">{label}</span>
      <div className="mt-1 flex gap-2">
        <input type="date" className="input" value={value} max={new Date().toISOString().split('T')[0]} min="1700-01-01" onChange={(e) => onChange(e.target.value)} />
        {value && <button type="button" onClick={() => onChange('')} className="btn-ghost h-12 px-3 text-sm">Clear</button>}
      </div>
    </label>
  )
}

function ExistingRelationships({
  member, members, rels, onChange,
}: { member: Member; members: Member[]; rels: Relationship[]; onChange: () => void }) {
  const byId = new Map(members.map((m) => [m.id, m]))
  const rows: { rel: Relationship; other: Member; role: string }[] = []
  for (const r of rels) {
    if ((r.type === 'spouse' || r.type === 'partner') && (r.from_member === member.id || r.to_member === member.id)) {
      const otherId = r.from_member === member.id ? r.to_member : r.from_member
      const other = byId.get(otherId); if (other) rows.push({ rel: r, other, role: 'Spouse' })
    } else if (r.type === 'parent' && r.to_member === member.id) {
      const other = byId.get(r.from_member); if (other) rows.push({ rel: r, other, role: 'Parent' })
    } else if (r.type === 'parent' && r.from_member === member.id) {
      const other = byId.get(r.to_member); if (other) rows.push({ rel: r, other, role: 'Child' })
    }
  }
  const removeRel = async (relId: string) => { await deleteRelationship(relId); onChange() }

  return (
    <div className="card p-6 mt-6">
      <h2 className="font-bold mb-3">Relationships</h2>
      {rows.length === 0 ? (
        <p className="text-sm text-ink/50">No relationships yet.</p>
      ) : (
        <div className="space-y-2">
          {rows.map(({ rel, other, role }) => (
            <div key={rel.id} className="flex items-center gap-3">
              <Avatar member={other} size={36} />
              <div className="flex-1 min-w-0">
                <div className="font-medium truncate">{fullName(other)}</div>
                <div className="text-xs text-ink/45">{role}</div>
              </div>
              <button onClick={() => removeRel(rel.id)} className="text-coral text-lg px-2" title="Remove">×</button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
