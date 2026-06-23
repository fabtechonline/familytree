import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useFamily } from '../../app/FamilyProvider'
import type { Family } from '../../lib/types'

export default function CreateFamilyPage() {
  const nav = useNavigate()
  const qc = useQueryClient()
  const { families, setCurrentId } = useFamily()
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const create = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.rpc('create_family', { p_name: name.trim() })
      if (error) throw error
      const family = (Array.isArray(data) ? data[0] : data) as Family
      await qc.invalidateQueries({ queryKey: ['my-families'] })
      if (family?.id) setCurrentId(family.id)
      nav('/app', { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create family')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-brand-50 to-canvas grid place-items-center px-5 py-10">
      <div className="w-full max-w-md">
        <div className="card p-8">
          <img src="/branding/icon_master.png" alt="" className="h-12 w-12 rounded-xl" />
          <h1 className="mt-4 text-2xl font-extrabold tracking-tight">
            {families.length === 0 ? 'Welcome to Riza' : 'Create a new family'}
          </h1>
          <p className="mt-1 text-sm text-ink/60">
            {families.length === 0
              ? 'Let’s start your family’s living history. What should we call it?'
              : 'Start another family space. You’ll be its admin.'}
          </p>
          <form onSubmit={create} className="mt-6 space-y-4">
            <div>
              <label className="text-sm font-medium">Family name</label>
              <input
                required
                autoFocus
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="input mt-1"
                placeholder="e.g. The Bux Family"
              />
            </div>
            {error && <p className="text-sm text-coral">{error}</p>}
            <button type="submit" disabled={loading || !name.trim()} className="btn-primary w-full">
              {loading ? 'Creating…' : 'Create family'}
            </button>
          </form>
        </div>
        {families.length > 0 && (
          <div className="mt-5 text-center text-sm text-ink/60">
            <Link to="/app" className="font-semibold text-brand-700">
              ← Back to {families.length === 1 ? 'your family' : 'your families'}
            </Link>
          </div>
        )}
      </div>
    </div>
  )
}
