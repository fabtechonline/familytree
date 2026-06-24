import { supabase } from './supabase'

const FN = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1`

async function call(fn: string, body: unknown) {
  const { data: sess } = await supabase.auth.getSession()
  const res = await fetch(`${FN}/${fn}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${sess.session?.access_token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const json = await res.json()
  if (!res.ok) throw new Error(json.error || `Error ${res.status}`)
  return json
}

/** Start a Paystack checkout; returns the authorization URL to redirect to. */
export function startCheckout(familyId: string, planKey: string): Promise<{ authorization_url: string; reference: string }> {
  return call('paystack-initialize', { familyId, planKey, callbackUrl: `${location.origin}/app/plans` })
}

export function cancelSubscription(familyId: string): Promise<{ ok: boolean }> {
  return call('paystack-cancel', { familyId })
}
