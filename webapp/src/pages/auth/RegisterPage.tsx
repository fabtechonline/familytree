import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import AuthLayout from './AuthLayout'

export default function RegisterPage() {
  const nav = useNavigate()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const register = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password.length < 6) {
      setError('Password must be at least 6 characters.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { display_name: name } },
      })
      if (error) throw error
      // If email confirmation is required, there's no active session yet.
      if (!data.session) {
        nav(`/app/verify?email=${encodeURIComponent(email)}&mode=signup`)
      } else {
        nav('/app', { replace: true })
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create account')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthLayout
      title="Create your family"
      subtitle="Start your family’s living history"
      footer={
        <>
          Already have an account?{' '}
          <Link to="/app/sign-in" className="font-semibold text-brand-700">
            Sign in
          </Link>
        </>
      }
    >
      <form onSubmit={register} className="space-y-4">
        <div>
          <label className="text-sm font-medium">Your name</label>
          <input
            type="text"
            autoComplete="name"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="input mt-1"
            placeholder="Jane Doe"
          />
        </div>
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
            autoComplete="new-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="input mt-1"
            placeholder="At least 6 characters"
          />
        </div>

        {error && <p className="text-sm text-coral">{error}</p>}

        <button type="submit" disabled={loading} className="btn-primary w-full">
          {loading ? 'Creating account…' : 'Create account'}
        </button>
      </form>
    </AuthLayout>
  )
}
