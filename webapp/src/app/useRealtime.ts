import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'

/**
 * Subscribe to all realtime-enabled tables for a family and invalidate the
 * matching React Query caches on any change — so edits from other members or
 * the mobile app appear live. Mirrors the Flutter app's realtime_provider.
 */
const TABLE_KEYS: Record<string, string[]> = {
  members: ['members'],
  relationships: ['relationships'],
  family_members: ['roster', 'my-families'],
  announcements: ['announcements'],
  member_media: ['member-media'],
  edit_suggestions: ['suggestions'],
}

export function useRealtime(familyId?: string) {
  const qc = useQueryClient()
  useEffect(() => {
    if (!familyId) return
    const channel = supabase.channel(`family:${familyId}`)
    for (const table of Object.keys(TABLE_KEYS)) {
      channel.on(
        'postgres_changes',
        { event: '*', schema: 'public', table, filter: `family_id=eq.${familyId}` },
        () => {
          for (const key of TABLE_KEYS[table]) {
            // Invalidate both family-scoped and global variants of the key.
            qc.invalidateQueries({ queryKey: [key, familyId] })
            qc.invalidateQueries({ queryKey: [key] })
          }
        },
      )
    }
    channel.subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
  }, [familyId, qc])
}
