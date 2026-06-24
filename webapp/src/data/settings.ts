import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'

export interface PublicSettings {
  features: { face_recognition: boolean; ai_avatar: boolean; data_export: boolean }
  announcement: string
  maintenance: { enabled: boolean; message: string }
  freeMemberLimit: number
}

const DEFAULTS: PublicSettings = {
  features: { face_recognition: true, ai_avatar: true, data_export: true },
  announcement: '',
  maintenance: { enabled: false, message: '' },
  freeMemberLimit: 50,
}

/** Public app settings (feature flags, announcement, maintenance) — readable by
 *  any signed-in user via RLS (the paystack/secret rows are excluded). */
export function usePublicSettings() {
  return useQuery({
    queryKey: ['public-settings'],
    staleTime: 60_000,
    queryFn: async (): Promise<PublicSettings> => {
      const { data, error } = await supabase.from('app_settings').select('key, value')
      if (error) throw error
      const map = Object.fromEntries(((data ?? []) as Array<{ key: string; value: unknown }>).map((r) => [r.key, r.value]))
      const support = (map.support ?? {}) as { announcement?: string }
      return {
        features: { ...DEFAULTS.features, ...((map.features as object) ?? {}) },
        announcement: support.announcement ?? '',
        maintenance: { ...DEFAULTS.maintenance, ...((map.maintenance as object) ?? {}) },
        freeMemberLimit: typeof map.free_member_limit === 'number' ? (map.free_member_limit as number) : 50,
      }
    },
  })
}
