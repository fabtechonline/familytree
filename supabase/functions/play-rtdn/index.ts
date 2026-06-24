// Google Play Real-time Developer Notifications (Pub/Sub push). Keeps a family's
// subscription state in sync on renewal/cancel/expiry by re-verifying the token
// against the Play Developer API (trust comes from that authenticated call, not
// the push payload). Configure a Pub/Sub push subscription to this URL; protect
// it with ?token=<RTDN_VERIFY_TOKEN>.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'

const SB_URL = Deno.env.get('SB_URL')!
const SECRET = Deno.env.get('SB_SECRET_KEY')!
const ANDROID_PKG = Deno.env.get('ANDROID_PACKAGE') ?? 'com.fabtechonline.riza'
const GOOGLE_SA = Deno.env.get('GOOGLE_PLAY_SA_JSON') ?? ''
const VERIFY_TOKEN = Deno.env.get('RTDN_VERIFY_TOKEN') ?? ''

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
}

async function subscriptionState(token: string): Promise<{ status: string; expiry: string | null; cancel: boolean }> {
  const sa = JSON.parse(GOOGLE_SA)
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, {
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token', iat: getNumericDate(0), exp: getNumericDate(3600),
  }, key)
  const tk = await (await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  })).json()
  const r = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PKG}/purchases/subscriptionsv2/tokens/${token}`,
    { headers: { Authorization: `Bearer ${tk.access_token}` } })
  const j = await r.json()
  const state = j.subscriptionState as string
  const map: Record<string, string> = {
    SUBSCRIPTION_STATE_ACTIVE: 'active',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace',
    SUBSCRIPTION_STATE_CANCELED: 'non_renewing',
    SUBSCRIPTION_STATE_ON_HOLD: 'grace',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
  }
  return {
    status: map[state] ?? 'expired',
    expiry: j.lineItems?.[0]?.expiryTime ?? null,
    cancel: state === 'SUBSCRIPTION_STATE_CANCELED',
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok')
  if (VERIFY_TOKEN && new URL(req.url).searchParams.get('token') !== VERIFY_TOKEN) {
    return new Response('forbidden', { status: 403 })
  }
  const svc = createClient(SB_URL, SECRET)
  try {
    const body = await req.json()
    const msg = body.message ?? {}
    const rtdn = JSON.parse(atob(msg.data ?? ''))
    const sn = rtdn.subscriptionNotification
    if (!sn) return new Response('ignored') // one-time / test notifications

    const ins = await svc.from('subscription_events').insert({
      provider: 'google_play', event_type: `rtdn_${sn.notificationType}`,
      external_id: `rtdn_${msg.messageId ?? sn.purchaseToken}`, payload: rtdn,
    }).select('id')
    if (ins.error?.code === '23505') return new Response('duplicate')

    const { data: fb } = await svc.from('family_billing').select('family_id').eq('google_purchase_token', sn.purchaseToken).maybeSingle()
    if (!fb) return new Response('no family')
    const familyId = fb.family_id

    // 13 EXPIRED, 12 REVOKED → expired immediately; 3 CANCELED → non-renewing.
    if (sn.notificationType === 13 || sn.notificationType === 12) {
      await svc.from('family_billing').update({ status: 'expired' }).eq('family_id', familyId)
    } else if (sn.notificationType === 3) {
      await svc.from('family_billing').update({ status: 'non_renewing', cancel_at_period_end: true }).eq('family_id', familyId)
    } else if (GOOGLE_SA) {
      const s = await subscriptionState(sn.purchaseToken)
      await svc.from('family_billing').update({
        status: s.status, current_period_end: s.expiry, cancel_at_period_end: s.cancel,
      }).eq('family_id', familyId)
    }
    await svc.rpc('recompute_family_tier', { p_family: familyId })
    return new Response('ok')
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : e}`, { status: 200 })
  }
})
