import { supabase } from './supabase'
import type { AvatarConfig } from './types'

const FN_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/generate-avatar`

/**
 * Premium: ask the `generate-avatar` edge function to analyze a member's photo
 * with Claude vision and return a matching DiceBear avatar config. Server-side
 * (the Anthropic key never touches the client).
 */
export async function generateAvatarFromPhoto(memberId: string): Promise<AvatarConfig> {
  const { data: sess } = await supabase.auth.getSession()
  const jwt = sess.session?.access_token
  if (!jwt) throw new Error('Not signed in')
  const res = await fetch(FN_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ memberId }),
  })
  if (!res.ok) {
    const t = await res.text().catch(() => '')
    throw new Error(`Generation failed: ${res.status} ${t}`)
  }
  return (await res.json()) as AvatarConfig
}
