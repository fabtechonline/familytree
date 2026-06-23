import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useFamily } from '../../app/FamilyProvider'
import { useCapsules } from '../../data/feature-queries'
import { supabase } from '../../lib/supabase'
import { canContribute } from '../../lib/types'
import { formatDate } from '../../lib/member-utils'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'

export default function CapsulesPage() {
  const { current } = useFamily()
  const qc = useQueryClient()
  const { data: capsules = [], isLoading } = useCapsules(current?.id)
  const mayCreate = canContribute(current?.myRole)

  const [open, setOpen] = useState(false)
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [unlock, setUnlock] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const seal = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!current) return
    setBusy(true)
    setError(null)
    try {
      const { data: auth } = await supabase.auth.getUser()
      const { error } = await supabase.from('legacy_capsules').insert({
        family_id: current.id,
        author_id: auth.user!.id,
        title: title.trim(),
        body: body.trim(),
        unlock_at: new Date(unlock).toISOString(),
      })
      if (error) throw error
      setTitle(''); setBody(''); setUnlock(''); setOpen(false)
      qc.invalidateQueries({ queryKey: ['capsules', current.id] })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not seal capsule')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Legacy capsules"
        subtitle="Seal a message to be opened on a future date"
        action={mayCreate && <button className="btn-primary" onClick={() => setOpen((o) => !o)}>{open ? 'Cancel' : 'New capsule'}</button>}
      />

      {open && (
        <form onSubmit={seal} className="card p-5 mb-6 space-y-4">
          <input required className="input" placeholder="Title (e.g. For my granddaughter)" value={title} onChange={(e) => setTitle(e.target.value)} />
          <textarea required rows={4} className="input !h-auto py-3" placeholder="Your message…" value={body} onChange={(e) => setBody(e.target.value)} />
          <label className="block">
            <span className="text-sm font-medium">Unlock on</span>
            <input required type="date" className="input mt-1 max-w-xs" value={unlock} onChange={(e) => setUnlock(e.target.value)} />
          </label>
          {error && <p className="text-sm text-coral">{error}</p>}
          <button disabled={busy || !title || !body || !unlock} className="btn-primary">{busy ? 'Sealing…' : 'Seal capsule 🔒'}</button>
        </form>
      )}

      {isLoading ? (
        <Spinner />
      ) : capsules.length === 0 ? (
        <EmptyState icon="capsule" title="No capsules yet" body="Write a message to the future — it stays sealed until the date you choose." />
      ) : (
        <div className="space-y-4">
          {capsules.map((c) => (
            <div key={c.id} className={`card p-5 ${c.locked ? 'border-dashed' : ''}`}>
              <div className="flex items-center justify-between">
                <h3 className="font-bold">{c.locked ? '🔒 ' : '🔓 '}{c.title}</h3>
                <span className="text-xs text-ink/45">
                  {c.locked ? `unlocks ${formatDate(c.unlock_at)}` : `opened ${formatDate(c.unlock_at)}`}
                </span>
              </div>
              {c.locked ? (
                <p className="mt-2 text-sm text-ink/40 italic">Sealed until {formatDate(c.unlock_at)}.</p>
              ) : (
                <p className="mt-2 text-sm text-ink/75 whitespace-pre-wrap">{c.body}</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
