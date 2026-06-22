// Edge Function: authorize a member-photo upload and return a signed upload URL.
//
// Why: this project's storage-api rejects end-user JWTs under the new asymmetric
// API keys, so direct client uploads fail. This function verifies the caller +
// family role, then mints a short-lived signed upload URL (service role) that
// the app PUTs bytes to directly — no auth needed on the upload, and no large
// payload through the function.
//
// Deploy: supabase functions deploy upload-photo --no-verify-jwt
// Secrets: SB_URL, SB_PUBLISHABLE_KEY, SB_SECRET_KEY
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const url = Deno.env.get('SB_URL')!;
  const publishable = Deno.env.get('SB_PUBLISHABLE_KEY')!;
  const secret = Deno.env.get('SB_SECRET_KEY')!;

  const jwt = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  if (!jwt) return json({ error: 'missing token' }, 401);

  const userClient = createClient(url, publishable);
  const { data: { user }, error: uErr } = await userClient.auth.getUser(jwt);
  if (uErr || !user) return json({ error: 'unauthorized' }, 401);

  let body: { familyId?: string; memberId?: string; folder?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad body' }, 400);
  }
  const { familyId, memberId, folder } = body;
  if (!familyId || !memberId) return json({ error: 'missing fields' }, 400);

  const svc = createClient(url, secret);

  // Authorize: admins/editors can upload for anyone; a "relative" can upload
  // only for the member linked to them (their own profile).
  const { data: member } = await svc
    .from('members')
    .select('linked_user_id, family_id')
    .eq('id', memberId)
    .maybeSingle();
  const isOwnProfile =
    member && member.family_id === familyId && member.linked_user_id === user.id;

  let allowed = !!isOwnProfile;
  if (!allowed) {
    const { data: fm } = await svc
      .from('family_members')
      .select('role')
      .eq('family_id', familyId)
      .eq('user_id', user.id)
      .maybeSingle();
    allowed = !!fm && ['admin', 'editor'].includes(fm.role);
  }
  if (!allowed) return json({ error: 'forbidden' }, 403);

  const ts = Date.now();
  const leaf = folder === 'memories' ? `memories/${ts}.jpg` : `avatar_${ts}.jpg`;
  const path = `${familyId}/${memberId}/${leaf}`;

  const { data: signed, error: sErr } = await svc.storage
    .from('member-photos')
    .createSignedUploadUrl(path);
  if (sErr || !signed) return json({ error: sErr?.message ?? 'sign failed' }, 500);

  const { data: pub } = svc.storage.from('member-photos').getPublicUrl(path);
  return json({
    signedUrl: signed.signedUrl,
    token: signed.token,
    path,
    publicUrl: pub.publicUrl,
  });
});
