// App Store Server Notifications v2. Syncs renewals/cancellations/refunds back
// to family_billing. Decodes the signed payload to find the subscription, then
// re-verifies the transaction against the App Store Server API for authoritative
// state. Set this URL as the production + sandbox notifications endpoint.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'

const SB_URL = Deno.env.get('SB_URL')!
const SECRET = Deno.env.get('SB_SECRET_KEY')!
const APPLE_KEY = Deno.env.get('APPLE_IAP_PRIVATE_KEY') ?? ''
const APPLE_KEY_ID = Deno.env.get('APPLE_IAP_KEY_ID') ?? ''
const APPLE_ISSUER = Deno.env.get('APPLE_IAP_ISSUER_ID') ?? ''
const APPLE_BUNDLE = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.fabtechonline.riza'

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
}
function b64urlJson(part: string): Record<string, unknown> {
  const b64 = part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=')
  return JSON.parse(atob(b64))
}

async function appleJwt(): Promise<string> {
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(APPLE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  return create({ alg: 'ES256', typ: 'JWT', kid: APPLE_KEY_ID }, {
    iss: APPLE_ISSUER, iat: getNumericDate(0), exp: getNumericDate(1200),
    aud: 'appstoreconnect-v1', bid: APPLE_BUNDLE,
  }, key)
}

async function verifyTransaction(transactionId: string) {
  const jwt = await appleJwt()
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const r = await fetch(`https://${host}/inApps/v1/transactions/${transactionId}`, { headers: { Authorization: `Bearer ${jwt}` } })
    if (!r.ok) continue
    const info = b64urlJson(((await r.json()).signedTransactionInfo as string).split('.')[1])
    return info
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok')
  const svc = createClient(SB_URL, SECRET)
  try {
    const { signedPayload } = await req.json()
    if (!signedPayload) return new Response('no payload')
    const payload = b64urlJson(signedPayload.split('.')[1])
    const type = payload.notificationType as string
    const subtype = payload.subtype as string | undefined
    const data = (payload.data ?? {}) as Record<string, unknown>
    const txInfo = data.signedTransactionInfo
      ? b64urlJson((data.signedTransactionInfo as string).split('.')[1])
      : null
    if (!txInfo) return new Response('no transaction')

    const origTx = txInfo.originalTransactionId as string
    const ins = await svc.from('subscription_events').insert({
      provider: 'apple', event_type: `${type}${subtype ? '/' + subtype : ''}`,
      external_id: `assn_${payload.notificationUUID ?? origTx}`, payload,
    }).select('id')
    if (ins.error?.code === '23505') return new Response('duplicate')

    const { data: fb } = await svc.from('family_billing').select('family_id, plan_key').eq('apple_original_transaction_id', origTx).maybeSingle()
    if (!fb) return new Response('no family')
    const familyId = fb.family_id

    const update: Record<string, unknown> = { updated_at: new Date().toISOString() }
    if (type === 'EXPIRED' || type === 'REVOKE' || type === 'REFUND' || type === 'GRACE_PERIOD_EXPIRED') {
      update.status = 'expired'
    } else if (type === 'DID_CHANGE_RENEWAL_STATUS' && subtype === 'AUTO_RENEW_DISABLED') {
      update.status = 'non_renewing'
      update.cancel_at_period_end = true
    } else {
      // DID_RENEW / SUBSCRIBED / DID_RECOVER / renewal re-enabled → re-verify for the expiry.
      const fresh = (APPLE_KEY ? await verifyTransaction(txInfo.transactionId as string) : null) ?? txInfo
      const expires = fresh.expiresDate ? new Date(fresh.expiresDate as number).toISOString() : null
      update.status = 'active'
      update.cancel_at_period_end = false
      update.current_period_end = fb.plan_key === 'lifetime' ? null : expires
    }
    await svc.from('family_billing').update(update).eq('family_id', familyId)
    await svc.rpc('recompute_family_tier', { p_family: familyId })
    return new Response('ok')
  } catch (e) {
    return new Response(`error: ${e instanceof Error ? e.message : e}`, { status: 200 })
  }
})
