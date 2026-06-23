import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import QRCode from 'qrcode'
import { supabase } from '../../lib/supabase'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers } from '../../data/queries'
import { useRoster } from '../../data/admin-queries'
import { isAdmin, type FamilyRole } from '../../lib/types'
import { fullName } from '../../lib/member-utils'
import { PageHeader, Spinner } from '../../components/ui'

const ROLES: { value: FamilyRole; label: string; desc: string }[] = [
  { value: 'viewer', label: 'Viewer', desc: 'Can view the tree only' },
  { value: 'relative', label: 'Relative', desc: 'Views all; edits their own profile' },
  { value: 'contributor', label: 'Contributor', desc: 'Suggests edits; posts to feed' },
  { value: 'editor', label: 'Editor', desc: 'Adds & edits members' },
  { value: 'admin', label: 'Admin', desc: 'Full control' },
]

export default function InvitePage() {
  const { current } = useFamily()
  const qc = useQueryClient()
  const admin = isAdmin(current?.myRole)
  const { data: roster = [], isLoading } = useRoster(current?.id)
  const { data: members = [] } = useMembers(current?.id)

  const [role, setRole] = useState<FamilyRole>('contributor')
  const [targetMember, setTargetMember] = useState('')
  const [code, setCode] = useState<string | null>(null)
  const [qr, setQr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  const joinUrl = code ? `${window.location.origin}/app/join?code=${code}` : ''

  const generate = async () => {
    if (!current) return
    setBusy(true)
    setError(null)
    setCode(null)
    try {
      const params: Record<string, unknown> = { p_family: current.id, p_role: role }
      if (role === 'relative' && targetMember) params.p_target_member = targetMember
      const { data, error } = await supabase.rpc('create_invitation', params)
      if (error) throw error
      const inv = Array.isArray(data) ? data[0] : data
      setCode(inv.code)
      setQr(await QRCode.toDataURL(`${window.location.origin}/app/join?code=${inv.code}`, { width: 240, margin: 1, color: { dark: '#0F1F1D', light: '#FFFFFF' } }))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create invite')
    } finally {
      setBusy(false)
    }
  }

  const copy = () => {
    navigator.clipboard.writeText(joinUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  const changeRole = async (userId: string, newRole: FamilyRole) => {
    await supabase.from('family_members').update({ role: newRole }).eq('family_id', current!.id).eq('user_id', userId)
    qc.invalidateQueries({ queryKey: ['roster', current!.id] })
  }

  return (
    <div className="max-w-3xl">
      <PageHeader
        title="Invite & roles"
        subtitle="Bring your family in and manage who can do what"
        action={<Link to="/app/join" className="btn-ghost">Join another family</Link>}
      />

      {!admin ? (
        <div className="card p-6 text-ink/60">Only family admins can create invites and manage roles.</div>
      ) : (
        <>
          <div className="card p-6">
            <h2 className="font-bold mb-4">Create an invite</h2>
            <div className="grid sm:grid-cols-2 gap-4">
              <label className="block">
                <span className="text-sm font-medium">Role</span>
                <select className="input mt-1" value={role} onChange={(e) => setRole(e.target.value as FamilyRole)}>
                  {ROLES.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
                </select>
                <span className="text-xs text-ink/45 mt-1 block">{ROLES.find((r) => r.value === role)?.desc}</span>
              </label>
              {role === 'relative' && (
                <label className="block">
                  <span className="text-sm font-medium">Link to which person?</span>
                  <select className="input mt-1" value={targetMember} onChange={(e) => setTargetMember(e.target.value)}>
                    <option value="">(optional)</option>
                    {members.map((m) => <option key={m.id} value={m.id}>{fullName(m)}</option>)}
                  </select>
                </label>
              )}
            </div>
            <button onClick={generate} disabled={busy} className="btn-primary mt-4">
              {busy ? 'Generating…' : 'Generate invite code'}
            </button>
            {error && <p className="text-sm text-coral mt-3">{error}</p>}

            {code && (
              <div className="mt-6 flex flex-col sm:flex-row gap-6 items-center border-t border-black/5 pt-6">
                {qr && <img src={qr} alt="Invite QR" className="h-40 w-40 rounded-xl border border-black/5" />}
                <div className="flex-1 w-full">
                  <div className="text-sm text-ink/50">Invite code</div>
                  <div className="text-3xl font-extrabold tracking-[0.2em] text-brand-700">{code}</div>
                  <div className="mt-3 flex gap-2">
                    <input readOnly value={joinUrl} className="input flex-1 text-sm" />
                    <button onClick={copy} className="btn-ghost h-12 px-4">{copied ? 'Copied!' : 'Copy link'}</button>
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="card p-6 mt-6">
            <h2 className="font-bold mb-4">Members ({roster.length})</h2>
            {isLoading ? (
              <Spinner />
            ) : (
              <div className="divide-y divide-black/5">
                {roster.map((r) => (
                  <div key={r.user_id} className="flex items-center justify-between gap-3 py-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="h-9 w-9 rounded-full bg-brand text-white grid place-items-center font-bold text-sm">
                        {(r.display_name || r.email || '?')[0].toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <div className="font-medium truncate">{r.display_name || r.email}</div>
                        <div className="text-xs text-ink/45 truncate">{r.email}</div>
                      </div>
                    </div>
                    <select
                      value={r.role}
                      onChange={(e) => changeRole(r.user_id, e.target.value as FamilyRole)}
                      className="rounded-lg border border-black/10 px-2 py-1.5 text-sm capitalize"
                    >
                      {ROLES.map((role) => <option key={role.value} value={role.value}>{role.label}</option>)}
                    </select>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}
