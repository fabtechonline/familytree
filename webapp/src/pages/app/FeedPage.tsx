import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useFamily } from '../../app/FamilyProvider'
import { useAnnouncements } from '../../data/feature-queries'
import { supabase } from '../../lib/supabase'
import { canContribute, type AnnouncementType } from '../../lib/types'
import { formatDate } from '../../lib/member-utils'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'
import Icon from '../../components/Icon'

const TYPES: { value: AnnouncementType; label: string; emoji: string }[] = [
  { value: 'news', label: 'News', emoji: '📣' },
  { value: 'birthday', label: 'Birthday', emoji: '🎂' },
  { value: 'birth', label: 'New baby', emoji: '👶' },
  { value: 'wedding', label: 'Wedding', emoji: '💍' },
  { value: 'anniversary', label: 'Anniversary', emoji: '💞' },
  { value: 'engagement', label: 'Engagement', emoji: '💐' },
  { value: 'graduation', label: 'Graduation', emoji: '🎓' },
  { value: 'new_job', label: 'New job', emoji: '💼' },
  { value: 'new_home', label: 'New home', emoji: '🏡' },
  { value: 'achievement', label: 'Achievement', emoji: '🏆' },
  { value: 'reunion', label: 'Reunion', emoji: '🎉' },
  { value: 'travel', label: 'Travel', emoji: '✈️' },
  { value: 'memorial', label: 'In memoriam', emoji: '🕊️' },
]
const emojiFor = (t: string) => TYPES.find((x) => x.value === t)?.emoji ?? '📣'
const labelFor = (t: string) => TYPES.find((x) => x.value === t)?.label ?? t

export default function FeedPage() {
  const { current } = useFamily()
  const qc = useQueryClient()
  const { data: posts = [], isLoading } = useAnnouncements(current?.id)
  const mayPost = canContribute(current?.myRole)

  const [open, setOpen] = useState(false)
  const [type, setType] = useState<AnnouncementType>('news')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const post = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!current) return
    setBusy(true)
    setError(null)
    try {
      const { data: auth } = await supabase.auth.getUser()
      const { error } = await supabase.from('announcements').insert({
        family_id: current.id,
        author_id: auth.user!.id,
        type,
        title: title.trim(),
        body: body.trim() || null,
      })
      if (error) throw error
      setTitle('')
      setBody('')
      setOpen(false)
      qc.invalidateQueries({ queryKey: ['announcements', current.id] })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not post')
    } finally {
      setBusy(false)
    }
  }

  const del = async (id: string) => {
    if (!confirm('Delete this post?')) return
    await supabase.from('announcements').delete().eq('id', id)
    qc.invalidateQueries({ queryKey: ['announcements', current?.id] })
  }

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Family feed"
        subtitle="News and milestones, just for your family"
        action={mayPost && <button className="btn-primary" onClick={() => setOpen((o) => !o)}>{open ? 'Cancel' : 'Share something'}</button>}
      />

      {open && (
        <form onSubmit={post} className="card p-5 mb-6 space-y-4">
          <div className="flex flex-wrap gap-2">
            {TYPES.map((t) => (
              <button
                type="button"
                key={t.value}
                onClick={() => setType(t.value)}
                className={`rounded-pill px-3 py-1.5 text-sm border ${type === t.value ? 'bg-brand text-white border-brand' : 'border-black/10 hover:border-brand/40'}`}
              >
                {t.emoji} {t.label}
              </button>
            ))}
          </div>
          <input required className="input" placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} />
          <textarea rows={3} className="input !h-auto py-3" placeholder="Say more (optional)…" value={body} onChange={(e) => setBody(e.target.value)} />
          {error && <p className="text-sm text-coral">{error}</p>}
          <button disabled={busy || !title.trim()} className="btn-primary">{busy ? 'Posting…' : 'Post to feed'}</button>
        </form>
      )}

      {isLoading ? (
        <Spinner />
      ) : posts.length === 0 ? (
        <EmptyState icon="feed" title="No posts yet" body="Share the first family update — a birth, a wedding, or just some news." />
      ) : (
        <div className="space-y-4">
          {posts.map((p) => (
            <div key={p.id} className="card p-5">
              <div className="flex items-start gap-3">
                <span className="text-2xl">{emojiFor(p.type)}</span>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <h3 className="font-bold">{p.title}</h3>
                    {mayPost && (
                      <button onClick={() => del(p.id)} title="Delete" aria-label="Delete post" className="text-ink/30 hover:text-coral p-1 -m-1">
                        <Icon name="trash" className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                  {p.body && <p className="mt-1 text-sm text-ink/70 whitespace-pre-wrap">{p.body}</p>}
                  <div className="mt-2 text-xs text-ink/40">{labelFor(p.type)} · {formatDate(p.created_at)}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
