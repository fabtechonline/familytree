// Edge Function: upload a member photo / memory to Storage.
//
// Why this exists: with this project's new asymmetric API keys, storage-api
// rejects end-user JWTs, so direct client uploads fail RLS. This function
// verifies the caller (via gotrue getUser) and their family role, then uploads
// with the SERVICE ROLE (which storage accepts), returning a public URL.
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

  // Verify the caller via gotrue.
  const userClient = createClient(url, publishable);
  const { data: { user }, error: uErr } = await userClient.auth.getUser(jwt);
  if (uErr || !user) return json({ error: 'unauthorized' }, 401);

  let body: {
    familyId?: string;
    memberId?: string;
    folder?: string;
    contentType?: string;
    dataBase64?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad body' }, 400);
  }
  const { familyId, memberId, folder, contentType, dataBase64 } = body;
  if (!familyId || !memberId || !dataBase64) {
    return json({ error: 'missing fields' }, 400);
  }

  const svc = createClient(url, secret);

  // Authorize: caller must be admin/editor of the family.
  const { data: fm } = await svc
    .from('family_members')
    .select('role')
    .eq('family_id', familyId)
    .eq('user_id', user.id)
    .maybeSingle();
  if (!fm || !['admin', 'editor'].includes(fm.role)) {
    return json({ error: 'forbidden' }, 403);
  }

  const bytes = Uint8Array.from(atob(dataBase64), (c) => c.charCodeAt(0));
  const ts = Date.now();
  const leaf = folder === 'memories' ? `memories/${ts}.jpg` : `avatar_${ts}.jpg`;
  const path = `${familyId}/${memberId}/${leaf}`;

  const { error: sErr } = await svc.storage
    .from('member-photos')
    .upload(path, bytes, { contentType: contentType ?? 'image/jpeg', upsert: true });
  if (sErr) return json({ error: sErr.message }, 500);

  const { data: pub } = svc.storage.from('member-photos').getPublicUrl(path);
  return json({ url: pub.publicUrl });
});
