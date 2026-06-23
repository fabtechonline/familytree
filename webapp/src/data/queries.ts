import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import type { Family, FamilyRole, Member, Relationship, Memory } from '../lib/types'

export interface FamilyWithRole extends Family {
  myRole: FamilyRole
}

/** Families the current user belongs to, with their role in each. */
export function useMyFamilies() {
  return useQuery({
    queryKey: ['my-families'],
    queryFn: async (): Promise<FamilyWithRole[]> => {
      const { data: auth } = await supabase.auth.getUser()
      if (!auth.user) return []
      const { data, error } = await supabase
        .from('family_members')
        .select('role, families:family_id (*)')
        .eq('user_id', auth.user.id)
      if (error) throw error
      const rows = (data ?? []) as Array<{ role: FamilyRole; families: Family | Family[] | null }>
      return rows
        .map((row) => {
          const fam = Array.isArray(row.families) ? row.families[0] : row.families
          return fam ? ({ ...fam, myRole: row.role } as FamilyWithRole) : null
        })
        .filter((f): f is FamilyWithRole => f !== null)
        .sort((a, b) => a.name.localeCompare(b.name))
    },
  })
}

/** All members (people) in a family. */
export function useMembers(familyId?: string) {
  return useQuery({
    queryKey: ['members', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<Member[]> => {
      const { data, error } = await supabase
        .from('members')
        .select('*')
        .eq('family_id', familyId!)
        .order('birth_date', { ascending: true, nullsFirst: false })
      if (error) throw error
      return data as Member[]
    },
  })
}

/** A single member by id. */
export function useMember(memberId?: string) {
  return useQuery({
    queryKey: ['member', memberId],
    enabled: !!memberId,
    queryFn: async (): Promise<Member | null> => {
      const { data, error } = await supabase
        .from('members')
        .select('*')
        .eq('id', memberId!)
        .maybeSingle()
      if (error) throw error
      return data as Member | null
    },
  })
}

/** Photo memories attached to a member. */
export function useMemberMedia(memberId?: string) {
  return useQuery({
    queryKey: ['member-media', memberId],
    enabled: !!memberId,
    queryFn: async (): Promise<Memory[]> => {
      const { data, error } = await supabase
        .from('member_media')
        .select('*')
        .eq('member_id', memberId!)
        .order('created_at', { ascending: false })
      if (error) throw error
      return data as Memory[]
    },
  })
}

/** All relationships (edges) in a family. */
export function useRelationships(familyId?: string) {
  return useQuery({
    queryKey: ['relationships', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<Relationship[]> => {
      const { data, error } = await supabase
        .from('relationships')
        .select('*')
        .eq('family_id', familyId!)
      if (error) throw error
      return data as Relationship[]
    },
  })
}
