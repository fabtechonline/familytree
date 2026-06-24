// Verify a native store purchase (Google Play or Apple) and grant the family
// premium. Called by the app after a purchase/restore. The trust comes from
// calling the store's authenticated server API — never from the client alone.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts'

const SB_URL = Deno.env.get('SB_URL')!
const PUBLISHABLE = Deno.env.get('SB_PUBLISHABLE_KEY')!
const SECRET = Deno.env.get('SB_SECRET_KEY')!
const ANDROID_PKG = Deno.env.get('ANDROID_PACKAGE') ?? 'com.fabtechonline.riza'
const GOOGLE_SA = Deno.env.get('GOOGLE_PLAY_SA_JSON') ?? ''
const APPLE_KEY = Deno.env.get('APPLE_IAP_PRIVATE_KEY') ?? ''
const APPLE_KEY_ID = Deno.env.get('APPLE_IAP_KEY_ID') ?? ''
const APPLE_ISSUER = Deno.env.get('APPLE_IAP_ISSUER_ID') ?? ''
const APPLE_BUNDLE = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.fabtechonline.riza'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, 'content-type': 'application/json' } })

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
}
function b64urlJson(part: string): Record<string, unknown> {
  const b64 = part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=')
  return JSON.parse(atob(b64))
}

async function googleAccessToken(): Promise<string> {
  const sa = JSON.parse(GOOGLE_SA)
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, {
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token', iat: getNumericDate(0), exp: getNumericDate(3600),
  }, key)
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  })
  const j = await r.json()
  if (!j.access_token) throw new Error('Google auth failed')
  return j.access_token
}

// Returns { active, periodEnd } or throws.
async function verifyGoogle(productId: string, token: string) {
  const access = await googleAccessToken()
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PKG}/purchases`
  if (productId === 'lifetime') {
    const r = await fetch(`${base}/products/${productId}/tokens/${token}`, { headers: { Authorization: `Bearer ${access}` } })
    const j = await r.json()
    return { active: j.purchaseState === 0, periodEnd: null as string | null }
  }
  const r = await fetch(`${base}/subscriptionsv2/tokens/${token}`, { headers: { Authorization: `Bearer ${access}` } })
  const j = await r.json()
  const state = j.subscriptionState
  const expiry = j.lineItems?.[0]?.expiryTime ?? null
  return { active: state === 'SUBSCRIPTION_STATE_ACTIVE' || state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', periodEnd: expiry }
}

async function verifyApple(productId: string, token: string) {
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(APPLE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const jwt = await create({ alg: 'ES256', typ: 'JWT', kid: APPLE_KEY_ID }, {
    iss: APPLE_ISSUER, iat: getNumericDate(0), exp: getNumericDate(1200),
    aud: 'appstoreconnect-v1', bid: APPLE_BUNDLE,
  }, key)
  // The client sends the StoreKit JWS; its payload carries the transactionId.
  const txId = (b64urlJson(token.split('.')[1]).transactionId as string) ?? token
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const r = await fetch(`https://${host}/inApps/v1/transactions/${txId}`, { headers: { Authorization: `Bearer ${jwt}` } })
    if (!r.ok) continue
    const signed = (await r.json()).signedTransactionInfo as string
    const info = b64urlJson(signed.split('.')[1])
    const expires = info.expiresDate ? new Date(info.expiresDate as number).toISOString() : null
    const active = !info.revocationDate && (productId === 'lifetime' || (info.expiresDate as number) > Date.now())
    return { active, periodEnd: productId === 'lifetime' ? null : expires, originalTransactionId: info.originalTransactionId as string }
  }
  throw new Error('Apple transaction not found')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const { familyId, productId, platform, token } = await req.json()
    if (!familyId || !productId || !token) return json({ error: 'familyId, productId, token required' }, 400)
    if (!['premium_monthly', 'premium_yearly', 'lifetime'].includes(productId)) return json({ error: 'Unknown product' }, 400)

    const userClient = createClient(SB_URL, PUBLISHABLE, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Not authenticated' }, 401)

    const svc = createClient(SB_URL, SECRET)
    const { data: fm } = await svc.from('family_members').select('role').eq('family_id', familyId).eq('user_id', user.id).maybeSingle()
    if (!fm || fm.role !== 'admin') return json({ error: 'Only the family admin can purchase' }, 403)

    const isApple = platform === 'apple'
    if (isApple && (!APPLE_KEY || !APPLE_KEY_ID || !APPLE_ISSUER)) return json({ error: 'Apple IAP is not configured yet.' }, 503)
    if (!isApple && !GOOGLE_SA) return json({ error: 'Google Play is not configured yet.' }, 503)

    const result = isApple ? await verifyApple(productId, token) : await verifyGoogle(productId, token)
    if (!result.active) return json({ ok: false, error: 'Purchase is not active' }, 200)

    await svc.from('family_billing').upsert({
      family_id: familyId, plan_key: productId,
      billing_provider: isApple ? 'apple' : 'google_play', status: 'active',
      is_comp: false, cancel_at_period_end: false,
      current_period_end: result.periodEnd, updated_at: new Date().toISOString(),
      ...(isApple
        ? { apple_original_transaction_id: (result as { originalTransactionId?: string }).originalTransactionId }
        : { google_purchase_token: token, google_product_id: productId }),
    })
    await svc.rpc('recompute_family_tier', { p_family: familyId })
    await svc.from('subscription_events').insert({
      family_id: familyId, provider: isApple ? 'apple' : 'google_play',
      event_type: 'verify', external_id: `verify_${productId}_${token.slice(0, 48)}`, payload: { productId },
    })
    return json({ ok: true })
  } catch (e) {
    return json({ ok: false, error: e instanceof Error ? e.message : 'Unexpected error' }, 500)
  }
})
