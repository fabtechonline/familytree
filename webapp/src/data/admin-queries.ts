import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { fetchMyProfile } from '../lib/profile'
import type { EditSuggestion, RosterMember, Profile } from '../lib/types'

export function useMyProfile() {
  return useQuery({ queryKey: ['my-profile'], queryFn: fetchMyProfile })
}

export function useRoster(familyId?: string) {
  return useQuery({
    queryKey: ['roster', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<RosterMember[]> => {
      const { data, error } = await supabase.rpc('family_roster', { p_family: familyId! })
      if (error) throw error
      return (data ?? []) as RosterMember[]
    },
  })
}

export function usePendingSuggestions(familyId?: string) {
  return useQuery({
    queryKey: ['suggestions', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<EditSuggestion[]> => {
      const { data, error } = await supabase
        .from('edit_suggestions')
        .select('*')
        .eq('family_id', familyId!)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
      if (error) throw error
      return data as EditSuggestion[]
    },
  })
}

export interface PlatformStats {
  total_users: number
  total_families: number
  premium_families: number
  blocked_users: number
}
export interface AdminFamily {
  id: string
  name: string
  subscription_tier: 'free' | 'premium'
  member_count: number
  person_count: number
  created_at: string
}

export function usePlatformStats(enabled: boolean) {
  return useQuery({
    queryKey: ['platform-stats'],
    enabled,
    queryFn: async (): Promise<PlatformStats> => {
      const { data, error } = await supabase.rpc('admin_platform_stats')
      if (error) throw error
      return (Array.isArray(data) ? data[0] : data) as PlatformStats
    },
  })
}

export function useAdminFamilies(enabled: boolean) {
  return useQuery({
    queryKey: ['admin-families'],
    enabled,
    queryFn: async (): Promise<AdminFamily[]> => {
      const { data, error } = await supabase.rpc('admin_list_families')
      if (error) throw error
      return (data ?? []) as AdminFamily[]
    },
  })
}

export type { Profile }
