import { supabase } from './supabase'
import type { Profile } from './types'

/** Fetch the current user's account profile (status, super-admin flag, etc.). */
export async function fetchMyProfile(): Promise<Profile | null> {
  const { data: auth } = await supabase.auth.getUser()
  if (!auth.user) return null
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', auth.user.id)
    .maybeSingle()
  if (error) throw error
  return data as Profile | null
}

export class AccountBlockedError extends Error {
  status: 'blocked' | 'suspended'
  constructor(status: 'blocked' | 'suspended') {
    super(
      status === 'blocked'
        ? 'Your account has been blocked. Please contact support.'
        : 'Your account is suspended. Please contact support.',
    )
    this.status = status
    this.name = 'AccountBlockedError'
  }
}

/** Throws AccountBlockedError if the signed-in account is not active. */
export async function assertAccountActive(): Promise<void> {
  const profile = await fetchMyProfile()
  if (profile && profile.status !== 'active') {
    await supabase.auth.signOut()
    throw new AccountBlockedError(profile.status)
  }
}
