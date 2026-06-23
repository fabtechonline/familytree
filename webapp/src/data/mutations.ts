import { supabase } from '../lib/supabase'
import { uploadMemberPhoto } from '../lib/upload'
import type { Member, RelType, RelSubtype } from '../lib/types'

export type MemberInput = Partial<Omit<Member, 'id' | 'created_at' | 'updated_at'>> & {
  family_id: string
  first_name: string
}

/** Clean a member form payload: empty strings → null for nullable fields. */
function clean<T extends Record<string, unknown>>(obj: T): T {
  const out = { ...obj }
  for (const k of Object.keys(out)) {
    if (out[k] === '') (out as Record<string, unknown>)[k] = null
  }
  return out
}

export async function createMember(input: MemberInput): Promise<Member> {
  const { data: auth } = await supabase.auth.getUser()
  const { data, error } = await supabase
    .from('members')
    .insert(clean({ ...input, created_by: auth.user?.id }))
    .select('*')
    .single()
  if (error) throw error
  return data as Member
}

export async function updateMember(id: string, patch: Partial<MemberInput>): Promise<Member> {
  const { data, error } = await supabase
    .from('members')
    .update(clean(patch))
    .eq('id', id)
    .select('*')
    .single()
  if (error) throw error
  return data as Member
}

export async function deleteMember(id: string): Promise<void> {
  const { error } = await supabase.from('members').delete().eq('id', id)
  if (error) throw error
}

export async function addRelationship(input: {
  family_id: string
  from_member: string
  to_member: string
  type: RelType
  subtype?: RelSubtype
}): Promise<void> {
  // Avoid duplicate unions (either direction), mirroring the mobile repository.
  if (input.type === 'spouse' || input.type === 'partner') {
    const { data: existing } = await supabase
      .from('relationships')
      .select('id')
      .eq('family_id', input.family_id)
      .in('type', ['spouse', 'partner'])
      .or(
        `and(from_member.eq.${input.from_member},to_member.eq.${input.to_member}),` +
          `and(from_member.eq.${input.to_member},to_member.eq.${input.from_member})`,
      )
    if (existing && existing.length > 0) return
  }
  // ON CONFLICT DO NOTHING against the (family, from, to, type) unique index.
  const { error } = await supabase.from('relationships').upsert(
    { subtype: 'biological', ...input },
    { onConflict: 'family_id,from_member,to_member,type', ignoreDuplicates: true },
  )
  if (error) throw error
}

export async function deleteRelationship(id: string): Promise<void> {
  const { error } = await supabase.from('relationships').delete().eq('id', id)
  if (error) throw error
}

/** Make newMemberId a sibling of siblingOfId by sharing the same parents. */
export async function linkSiblingByParents(input: {
  family_id: string
  newMemberId: string
  siblingOfId: string
}): Promise<void> {
  const { data: rows, error } = await supabase
    .from('relationships')
    .select('from_member')
    .eq('family_id', input.family_id)
    .eq('type', 'parent')
    .eq('to_member', input.siblingOfId)
  if (error) throw error
  for (const row of rows ?? []) {
    await addRelationship({
      family_id: input.family_id,
      from_member: (row as { from_member: string }).from_member,
      to_member: input.newMemberId,
      type: 'parent',
    })
  }
}

/** Add a photo memory: upload via the edge function, then record the row. */
export async function addMemory(input: {
  familyId: string
  memberId: string
  file: File
  caption?: string
}): Promise<void> {
  const url = await uploadMemberPhoto({
    familyId: input.familyId,
    memberId: input.memberId,
    folder: 'memories',
    file: input.file,
  })
  const { data: auth } = await supabase.auth.getUser()
  const { error } = await supabase.from('member_media').insert({
    family_id: input.familyId,
    member_id: input.memberId,
    uploaded_by: auth.user?.id,
    media_url: url,
    caption: input.caption?.trim() || null,
  })
  if (error) throw error
}

export async function deleteMemory(id: string): Promise<void> {
  const { error } = await supabase.from('member_media').delete().eq('id', id)
  if (error) throw error
}

/** Contributor suggestion (add or edit a member) → approval queue. */
export async function submitSuggestion(input: {
  family_id: string
  kind: 'add_member' | 'edit_member'
  payload: Record<string, unknown>
  target_member_id?: string
  note?: string
}): Promise<void> {
  const { data: auth } = await supabase.auth.getUser()
  const { error } = await supabase.from('edit_suggestions').insert({
    family_id: input.family_id,
    suggested_by: auth.user?.id,
    kind: input.kind,
    payload: input.payload,
    target_member_id: input.target_member_id ?? null,
    note: input.note ?? null,
  })
  if (error) throw error
}
