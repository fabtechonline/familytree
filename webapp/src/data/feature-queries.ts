import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import type { Announcement, Capsule } from '../lib/types'

export function useAnnouncements(familyId?: string) {
  return useQuery({
    queryKey: ['announcements', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<Announcement[]> => {
      const { data, error } = await supabase
        .from('announcements')
        .select('*')
        .eq('family_id', familyId!)
        .order('created_at', { ascending: false })
      if (error) throw error
      return data as Announcement[]
    },
  })
}

export function useCapsules(familyId?: string) {
  return useQuery({
    queryKey: ['capsules', familyId],
    enabled: !!familyId,
    queryFn: async (): Promise<Capsule[]> => {
      const { data, error } = await supabase.rpc('list_capsules', { p_family: familyId! })
      if (error) throw error
      return (data ?? []) as Capsule[]
    },
  })
}
