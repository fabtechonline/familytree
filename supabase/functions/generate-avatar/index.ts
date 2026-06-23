// Premium: analyze a member's photo with Claude vision and return a DiceBear
// "adventurer" avatar config. The Anthropic key is a server-side secret; the
// client only sends its JWT + memberId. Premium-gated.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SB_URL')!
const PUBLISHABLE_KEY = Deno.env.get('SB_PUBLISHABLE_KEY')!
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!

// Must match webapp/src/lib/avatar.ts + lib/src/features/avatars/dicebear.dart.
const SKIN_TONES = ['f2d3b1', 'ecad80', 'eeb592', 'd08b5b', '9e5622', '763900']
const HAIR_COLORS = ['0e0e0e', '3a2a1d', '6a4e35', '796a45', 'b9a05f', 'e5c07b', 'ac6511', 'cb6820', 'afafaf', 'dba3be']
const HAIR_STYLES = ['short01', 'short02', 'short04', 'short07', 'short11', 'short16', 'long01', 'long07', 'long13', 'long20']

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const SCHEMA = {
  type: 'object',
  properties: {
    skinColor: { type: 'string', enum: SKIN_TONES },
    hairColor: { type: 'string', enum: HAIR_COLORS },
    hair: { type: 'string', enum: HAIR_STYLES },
    glasses: { type: 'boolean' },
  },
  required: ['skinColor', 'hairColor', 'hair', 'glasses'],
  additionalProperties: false,
}

const PROMPT =
  'Look at this photo of a person and choose the closest matching illustrated-avatar ' +
  'features from the allowed options. Pick the nearest skin tone and hair colour from the ' +
  'provided hex palettes, the hair style whose length/shape best matches, and whether they ' +
  'wear glasses. If the face is unclear, make your best reasonable guess. Respond using the ' +
  'required JSON schema only.'

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'content-type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const { memberId } = await req.json()
    if (!memberId) return json({ error: 'memberId required' }, 400)

    // User-scoped client (RLS enforced) — verifies the caller and their access.
    const supabase = createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: auth } = await supabase.auth.getUser()
    if (!auth.user) return json({ error: 'Not authenticated' }, 401)

    // RLS ensures the caller can only read members of families they belong to.
    const { data: member } = await supabase
      .from('members')
      .select('photo_url, family_id')
      .eq('id', memberId)
      .maybeSingle()
    if (!member) return json({ error: 'Member not found' }, 404)
    if (!member.photo_url) return json({ error: 'Member has no photo' }, 400)

    // Premium gate.
    const { data: family } = await supabase
      .from('families')
      .select('subscription_tier')
      .eq('id', member.family_id)
      .maybeSingle()
    if (family?.subscription_tier !== 'premium') {
      return json({ error: 'AI avatar is a Premium feature' }, 403)
    }

    // Claude vision → structured features.
    const aiResp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5',
        max_tokens: 400,
        output_config: { format: { type: 'json_schema', schema: SCHEMA } },
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'url', url: member.photo_url } },
              { type: 'text', text: PROMPT },
            ],
          },
        ],
      }),
    })
    if (!aiResp.ok) {
      const text = await aiResp.text()
      return json({ error: `Claude error ${aiResp.status}: ${text.slice(0, 300)}` }, 502)
    }
    const ai = await aiResp.json()
    const textBlock = (ai.content ?? []).find((b: { type: string }) => b.type === 'text')
    if (!textBlock) return json({ error: 'No content from Claude' }, 502)
    const f = JSON.parse(textBlock.text)

    const config = {
      style: 'adventurer',
      seed: String(memberId).slice(0, 8),
      options: {
        skinColor: f.skinColor,
        hairColor: f.hairColor,
        hair: f.hair,
        glassesProbability: f.glasses ? 100 : 0,
      },
    }
    return json(config)
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'Unexpected error' }, 500)
  }
})
