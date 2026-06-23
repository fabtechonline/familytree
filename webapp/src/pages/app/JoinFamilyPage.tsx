import { useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useFamily } from '../../app/FamilyProvider'
import type { InvitePreview } from '../../lib/types'
import { PageHeader } from '../../components/ui'

export default function JoinFamilyPage() {
  const nav = useNavigate()
  const qc = useQueryClient()
  const { setCurrentId } = useFamily()
  const [params] = useSearchParams()
  const [code, setCode] = useState(params.get('code') ?? '')
  const [preview, setPreview] = useState<InvitePreview | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const doPreview = async (c: string) => {
    setError(null)
    setPreview(null)
    if (!c.trim()) return
    const { data, error } = await supabase.rpc('invite_preview', { p_code: c.trim() })
    if (error) {
      setError(error.message)
      return
    }
    const p = (Array.isArray(data) ? data[0] : data) as InvitePreview | undefined
    if (!p) setError('That code wasn’t found.')
    else setPreview(p)
  }

  useEffect(() => {
    if (params.get('code')) doPreview(params.get('code')!)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const join = async () => {
    setBusy(true)
    setError(null)
    try {
      const { data, error } = await supabase.rpc('join_family_with_code', { p_code: code.trim() })
      if (error) throw error
      const fam = Array.isArray(data) ? data[0] : data
      await qc.invalidateQueries({ queryKey: ['my-families'] })
      if (fam?.id) setCurrentId(fam.id)
      nav('/app', { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not join')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="max-w-md">
      <PageHeader title="Join a family" subtitle="Enter the invite code you were given" />
      <div className="card p-6 space-y-4">
        <div className="flex gap-2">
          <input
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            onBlur={() => doPreview(code)}
            placeholder="Invite code"
            className="input flex-1 tracking-[0.2em] font-bold uppercase"
          />
          <button onClick={() => doPreview(code)} className="btn-ghost h-12 px-4">Check</button>
        </div>

        {error && <p className="text-sm text-coral">{error}</p>}

        {preview && (
          <div className={`rounded-xl p-4 ${preview.valid ? 'bg-brand-50' : 'bg-coral/10'}`}>
            {preview.valid ? (
              <>
                <p className="font-bold text-brand-800">{preview.family_name}</p>
                <p className="text-sm text-ink/60 mt-0.5">
                  You’ll join as <span className="font-semibold capitalize">{preview.role}</span>
                  {preview.target_member_name ? `, linked to ${preview.target_member_name}` : ''}.
                </p>
                <button onClick={join} disabled={busy} className="btn-primary w-full mt-4">
                  {busy ? 'Joining…' : `Join ${preview.family_name}`}
                </button>
              </>
            ) : (
              <p className="text-sm text-coral">This invite has expired. Ask for a new code.</p>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
