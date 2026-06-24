// Cancel a family's Paystack subscription (admin only). Disables auto-renewal;
// the family stays premium until the current period ends (webhook flips it).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SB_URL = Deno.env.get('SB_URL')!
const PUBLISHABLE = Deno.env.get('SB_PUBLISHABLE_KEY')!
const SECRET = Deno.env.get('SB_SECRET_KEY')!
const PAYSTACK = Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, 'content-type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    if (!PAYSTACK) return json({ error: 'Paystack is not configured yet.' }, 503)
    const authHeader = req.headers.get('Authorization') ?? ''
    const { familyId } = await req.json()
    if (!familyId) return json({ error: 'familyId required' }, 400)

    const userClient = createClient(SB_URL, PUBLISHABLE, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Not authenticated' }, 401)

    const svc = createClient(SB_URL, SECRET)
    const { data: fm } = await svc.from('family_members').select('role').eq('family_id', familyId).eq('user_id', user.id).maybeSingle()
    if (!fm || fm.role !== 'admin') return json({ error: 'Only the family admin can cancel' }, 403)

    const { data: billing } = await svc.from('family_billing').select('paystack_subscription_code').eq('family_id', familyId).maybeSingle()
    const code = billing?.paystack_subscription_code
    if (!code) return json({ error: 'No active Paystack subscription to cancel' }, 400)

    // Disabling a subscription needs its email_token (fetched from the sub).
    const sub = await fetch(`https://api.paystack.co/subscription/${code}`, { headers: { Authorization: `Bearer ${PAYSTACK}` } })
    const subJson = await sub.json()
    const token = subJson.data?.email_token
    const dis = await fetch('https://api.paystack.co/subscription/disable', {
      method: 'POST',
      headers: { Authorization: `Bearer ${PAYSTACK}`, 'content-type': 'application/json' },
      body: JSON.stringify({ code, token }),
    })
    const disJson = await dis.json()
    if (!dis.ok || !disJson.status) return json({ error: `Paystack: ${disJson.message || dis.status}` }, 502)

    await svc.from('family_billing').update({ status: 'non_renewing', cancel_at_period_end: true }).eq('family_id', familyId)
    await svc.rpc('recompute_family_tier', { p_family: familyId })
    return json({ ok: true })
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'Unexpected error' }, 500)
  }
})
