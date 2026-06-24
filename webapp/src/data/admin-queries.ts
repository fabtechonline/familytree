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
  is_suspended: boolean
  plan_key: string
  current_period_end: string | null
  is_comp: boolean
}

export interface AdminPlan {
  key: string
  label: string
  tier: 'free' | 'premium'
  price_cents: number
  currency: string
  interval: 'none' | 'month' | 'year' | 'once'
  store_product_id: string | null
  paystack_plan_code: string | null
  is_active: boolean
  sort: number
}

export interface AppSetting {
  key: string
  value: Record<string, unknown> | number | string | boolean
  is_public: boolean
  updated_at: string
}

export interface Analytics {
  total_users: number
  blocked_users: number
  total_families: number
  suspended_families: number
  premium_families: number
  free_families: number
  lifetime_families: number
  comp_families: number
  new_families_30d: number
  total_members: number
  mrr_cents: number
  plan_distribution: Record<string, number>
}

export function useAnalytics(enabled: boolean) {
  return useQuery({
    queryKey: ['admin-analytics'],
    enabled,
    queryFn: async (): Promise<Analytics> => {
      const { data, error } = await supabase.rpc('admin_analytics')
      if (error) throw error
      return data as Analytics
    },
  })
}

export function usePlans(enabled: boolean) {
  return useQuery({
    queryKey: ['admin-plans'],
    enabled,
    queryFn: async (): Promise<AdminPlan[]> => {
      const { data, error } = await supabase.from('plans').select('*').order('sort')
      if (error) throw error
      return (data ?? []) as AdminPlan[]
    },
  })
}

export function useAppSettings(enabled: boolean) {
  return useQuery({
    queryKey: ['admin-settings'],
    enabled,
    queryFn: async (): Promise<AppSetting[]> => {
      const { data, error } = await supabase.rpc('admin_get_settings')
      if (error) throw error
      return (data ?? []) as AppSetting[]
    },
  })
}

export function useFamilyDetail(familyId: string | null) {
  return useQuery({
    queryKey: ['admin-family-detail', familyId],
    enabled: !!familyId,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_family_detail', { p_family: familyId! })
      if (error) throw error
      return data as {
        family: Record<string, unknown>
        billing: Record<string, unknown> | null
        member_count: number
        user_count: number
        events: Array<Record<string, unknown>>
      }
    },
  })
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
