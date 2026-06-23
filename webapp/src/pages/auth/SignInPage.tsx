import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { assertAccountActive } from '../../lib/profile'
import AuthLayout from './AuthLayout'

export default function SignInPage() {
  const nav = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const signInWithPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      await assertAccountActive()
      nav('/app', { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed')
    } finally {
      setLoading(false)
    }
  }

  const emailMeACode = async () => {
    if (!email) {
      setError('Enter your email first, then tap “Email me a code”.')
      return
    }
    setLoading(true)
    setError(null)
    setNotice(null)
    try {
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: { shouldCreateUser: false },
      })
      if (error) throw error
      setNotice('We sent a 6-digit code to your email.')
      nav(`/app/verify?email=${encodeURIComponent(email)}&mode=signin`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send code')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthLayout
      title="Welcome back"
      subtitle="Sign in to your family"
      footer={
        <>
          New to Riza?{' '}
          <Link to="/app/register" className="font-semibold text-brand-700">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={signInWithPassword} className="space-y-4">
        <div>
          <label className="text-sm font-medium">Email address</label>
          <input
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="input mt-1"
            placeholder="you@example.com"
          />
        </div>
        <div>
          <label className="text-sm font-medium">Password</label>
          <input
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="input mt-1"
            placeholder="••••••••"
          />
        </div>

        {error && <p className="text-sm text-coral">{error}</p>}
        {notice && <p className="text-sm text-brand-700">{notice}</p>}

        <button type="submit" disabled={loading} className="btn-primary w-full">
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>

      <div className="my-5 flex items-center gap-3 text-xs text-ink/40">
        <span className="h-px flex-1 bg-black/10" /> or <span className="h-px flex-1 bg-black/10" />
      </div>

      <button onClick={emailMeACode} disabled={loading} className="btn-ghost w-full">
        Email me a code instead
      </button>
    </AuthLayout>
  )
}
