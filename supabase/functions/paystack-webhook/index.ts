// Paystack webhook — the authoritative source for subscription state. Validates
// the signature, then updates family_billing and recomputes the family's tier.
// Idempotent via subscription_events.external_id.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'node:crypto'

const SB_URL = Deno.env.get('SB_URL')!
const SECRET = Deno.env.get('SB_SECRET_KEY')!
const PAYSTACK = Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''

function nextPeriod(planKey: string): string {
  const d = new Date()
  if (planKey === 'premium_yearly') d.setFullYear(d.getFullYear() + 1)
  else d.setMonth(d.getMonth() + 1)
  return d.toISOString()
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok')
  const body = await req.text()
  const sig = req.headers.get('x-paystack-signature') ?? ''
  if (!PAYSTACK || createHmac('sha512', PAYSTACK).update(body).digest('hex') !== sig) {
    return new Response('invalid signature', { status: 401 })
  }

  const evt = JSON.parse(body)
  const data = evt.data ?? {}
  const meta = data.metadata ?? {}
  const svc = createClient(SB_URL, SECRET)
  const customer = data.customer?.customer_code as string | undefined

  // Idempotency + audit: unique external_id per event.
  const externalId = `${evt.event}_${data.id ?? data.reference ?? customer ?? crypto.randomUUID()}`
  const ins = await svc.from('subscription_events').insert({
    family_id: meta.familyId ?? null, provider: 'paystack', event_type: evt.event,
    external_id: externalId, amount_cents: data.amount ?? null, currency: data.currency ?? null, payload: evt,
  }).select('id')
  if (ins.error?.code === '23505') return new Response('duplicate')

  const familyByCustomer = async (code?: string) => {
    if (!code) return undefined
    const { data: r } = await svc.from('family_billing').select('family_id').eq('paystack_customer_code', code).maybeSingle()
    return r?.family_id as string | undefined
  }
  let familyId: string | undefined = meta.familyId

  switch (evt.event) {
    case 'charge.success': {
      if (!familyId) break
      const planKey = meta.planKey ?? 'premium_monthly'
      const lifetime = planKey === 'lifetime'
      await svc.from('family_billing').upsert({
        family_id: familyId, plan_key: planKey, billing_provider: 'paystack', status: 'active',
        is_comp: false, cancel_at_period_end: false, paystack_customer_code: customer,
        current_period_end: lifetime ? null : nextPeriod(planKey), updated_at: new Date().toISOString(),
      })
      await svc.rpc('recompute_family_tier', { p_family: familyId })
      break
    }
    case 'subscription.create': {
      familyId = familyId ?? await familyByCustomer(customer)
      if (!familyId) break
      await svc.from('family_billing').update({
        paystack_subscription_code: data.subscription_code, status: 'active',
        current_period_end: data.next_payment_date ?? null, updated_at: new Date().toISOString(),
      }).eq('family_id', familyId)
      await svc.rpc('recompute_family_tier', { p_family: familyId })
      break
    }
    case 'invoice.create':
    case 'invoice.update': {
      familyId = familyId ?? await familyByCustomer(customer)
      const next = data.subscription?.next_payment_date
      if (familyId && next) {
        await svc.from('family_billing').update({ current_period_end: next, status: 'active' }).eq('family_id', familyId)
        await svc.rpc('recompute_family_tier', { p_family: familyId })
      }
      break
    }
    case 'subscription.not_renewing': {
      familyId = familyId ?? await familyByCustomer(customer)
      if (familyId) {
        await svc.from('family_billing').update({ status: 'non_renewing', cancel_at_period_end: true }).eq('family_id', familyId)
        await svc.rpc('recompute_family_tier', { p_family: familyId })
      }
      break
    }
    case 'subscription.disable': {
      familyId = familyId ?? await familyByCustomer(customer)
      if (familyId) {
        await svc.from('family_billing').update({ status: 'expired' }).eq('family_id', familyId)
        await svc.rpc('recompute_family_tier', { p_family: familyId })
      }
      break
    }
  }
  return new Response('ok')
})
