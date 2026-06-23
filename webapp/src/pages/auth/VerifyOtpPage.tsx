import { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { assertAccountActive } from '../../lib/profile'
import AuthLayout from './AuthLayout'

export default function VerifyOtpPage() {
  const nav = useNavigate()
  const [params] = useSearchParams()
  const email = params.get('email') ?? ''
  const mode = params.get('mode') ?? 'signin' // 'signin' | 'signup'

  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [resent, setResent] = useState(false)

  const verify = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const { error } = await supabase.auth.verifyOtp({
        email,
        token: code.trim(),
        type: mode === 'signup' ? 'signup' : 'email',
      })
      if (error) throw error
      await assertAccountActive()
      nav('/app', { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid or expired code')
    } finally {
      setLoading(false)
    }
  }

  const resend = async () => {
    setError(null)
    try {
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: { shouldCreateUser: mode === 'signup' },
      })
      if (error) throw error
      setResent(true)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not resend code')
    }
  }

  return (
    <AuthLayout
      title="Enter your code"
      subtitle={`We sent a 6-digit code to ${email || 'your email'}`}
      footer={
        <Link to="/app/sign-in" className="font-semibold text-brand-700">
          Back to sign in
        </Link>
      }
    >
      <form onSubmit={verify} className="space-y-4">
        <input
          inputMode="numeric"
          autoComplete="one-time-code"
          required
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          className="input mt-1 text-center text-2xl tracking-[0.5em] font-bold"
          placeholder="000000"
        />
        {error && <p className="text-sm text-coral">{error}</p>}
        {resent && <p className="text-sm text-brand-700">A new code is on its way.</p>}
        <button type="submit" disabled={loading || code.length < 6} className="btn-primary w-full">
          {loading ? 'Verifying…' : 'Verify & continue'}
        </button>
      </form>
      <button onClick={resend} className="btn-ghost w-full mt-3">
        Resend code
      </button>
    </AuthLayout>
  )
}
