// Start a Paystack checkout for a family's plan upgrade. Verifies the caller is
// the family admin, looks up the plan price/code, and returns an authorization
// URL to redirect to. The webhook is the authoritative source of truth.
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
    const { familyId, planKey, callbackUrl } = await req.json()
    if (!familyId || !planKey) return json({ error: 'familyId and planKey required' }, 400)

    const userClient = createClient(SB_URL, PUBLISHABLE, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Not authenticated' }, 401)

    const svc = createClient(SB_URL, SECRET)
    const { data: fm } = await svc.from('family_members').select('role').eq('family_id', familyId).eq('user_id', user.id).maybeSingle()
    if (!fm || fm.role !== 'admin') return json({ error: 'Only the family admin can upgrade' }, 403)

    const { data: plan } = await svc.from('plans').select('*').eq('key', planKey).maybeSingle()
    if (!plan || plan.tier !== 'premium' || !plan.is_active) return json({ error: 'Invalid plan' }, 400)

    const payload: Record<string, unknown> = {
      email: user.email,
      amount: plan.price_cents,
      currency: plan.currency || 'ZAR',
      metadata: { familyId, planKey, userId: user.id },
      callback_url: callbackUrl,
    }
    // Recurring plans carry a Paystack plan code; lifetime is a one-time charge.
    if (plan.interval !== 'once' && plan.paystack_plan_code) payload.plan = plan.paystack_plan_code

    const resp = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: { Authorization: `Bearer ${PAYSTACK}`, 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    })
    const data = await resp.json()
    if (!resp.ok || !data.status) return json({ error: `Paystack: ${data.message || resp.status}` }, 502)

    await svc.from('subscription_events').insert({
      family_id: familyId, provider: 'paystack', event_type: 'initialize',
      external_id: `init_${data.data.reference}`, amount_cents: plan.price_cents,
      currency: plan.currency, payload: { planKey },
    })
    return json({ authorization_url: data.data.authorization_url, reference: data.data.reference })
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'Unexpected error' }, 500)
  }
})
