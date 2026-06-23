import { supabase } from './supabase'

const FUNCTIONS_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/upload-photo`

interface SignResponse {
  signedUrl: string
  token: string
  path: string
  publicUrl: string
}

/**
 * Upload a member photo via the `upload-photo` edge function, which mints a
 * signed upload URL (the user JWT can't write to storage directly). Returns the
 * public URL to store on the member / member_media row.
 */
export async function uploadMemberPhoto(opts: {
  familyId: string
  memberId: string
  folder: 'avatar' | 'memories'
  file: File
}): Promise<string> {
  const { data: sess } = await supabase.auth.getSession()
  const jwt = sess.session?.access_token
  if (!jwt) throw new Error('Not signed in')

  const res = await fetch(FUNCTIONS_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      familyId: opts.familyId,
      memberId: opts.memberId,
      folder: opts.folder,
    }),
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`Upload authorization failed: ${res.status} ${text}`)
  }
  const sign = (await res.json()) as SignResponse

  // PUT the bytes to the signed URL (no auth header required).
  const put = await fetch(sign.signedUrl, {
    method: 'PUT',
    headers: { 'Content-Type': opts.file.type || 'image/jpeg' },
    body: opts.file,
  })
  if (!put.ok) throw new Error(`Photo upload failed: ${put.status}`)

  // Cache-bust so the new image shows immediately.
  return `${sign.publicUrl}?v=${Date.now()}`
}
