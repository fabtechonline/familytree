import { useState } from 'react'
import { useAuth } from '../../auth/AuthProvider'
import { supabase } from '../../lib/supabase'
import { PageHeader } from '../../components/ui'

export default function AccountPage() {
  const { session } = useAuth()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setDone(false)
    if (password.length < 6) {
      setError('Password must be at least 6 characters.')
      return
    }
    if (password !== confirm) {
      setError('Passwords don’t match.')
      return
    }
    setBusy(true)
    try {
      const { error } = await supabase.auth.updateUser({ password })
      if (error) throw error
      setDone(true)
      setPassword('')
      setConfirm('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update password')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="max-w-md">
      <PageHeader title="Account" subtitle="Manage your sign-in" />

      <div className="card p-6 mb-6">
        <div className="text-sm text-ink/50">Signed in as</div>
        <div className="font-semibold">{session?.user.email}</div>
      </div>

      <form onSubmit={submit} className="card p-6 space-y-4">
        <h2 className="font-bold">Set / change password</h2>
        <p className="text-sm text-ink/55">
          Use this to set a password (e.g. if you usually sign in with an email code) or change your existing one.
        </p>
        <div>
          <label className="text-sm font-medium">New password</label>
          <input
            type="password"
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="input mt-1"
            placeholder="At least 6 characters"
          />
        </div>
        <div>
          <label className="text-sm font-medium">Confirm password</label>
          <input
            type="password"
            autoComplete="new-password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            className="input mt-1"
            placeholder="Re-enter password"
          />
        </div>
        {error && <p className="text-sm text-coral">{error}</p>}
        {done && <p className="text-sm text-brand-700">Password updated ✓</p>}
        <button type="submit" disabled={busy} className="btn-primary">
          {busy ? 'Saving…' : 'Update password'}
        </button>
      </form>
    </div>
  )
}
