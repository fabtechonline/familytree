import { useQueryClient } from '@tanstack/react-query'
import { useFamily } from '../../app/FamilyProvider'
import { useMembers } from '../../data/queries'
import { usePendingSuggestions } from '../../data/admin-queries'
import { supabase } from '../../lib/supabase'
import { isAdmin } from '../../lib/types'
import { fullName } from '../../lib/member-utils'
import { PageHeader, Spinner, EmptyState } from '../../components/ui'

export default function SuggestionsPage() {
  const { current } = useFamily()
  const qc = useQueryClient()
  const admin = isAdmin(current?.myRole)
  const { data: suggestions = [], isLoading } = usePendingSuggestions(admin ? current?.id : undefined)
  const { data: members = [] } = useMembers(current?.id)

  const refresh = () => qc.invalidateQueries({ queryKey: ['suggestions', current?.id] })

  const approve = async (id: string) => {
    const { error } = await supabase.rpc('apply_suggestion', { p_id: id })
    if (error) return alert(error.message)
    qc.invalidateQueries({ queryKey: ['members', current?.id] })
    refresh()
  }
  const reject = async (id: string) => {
    await supabase.from('edit_suggestions').update({ status: 'rejected', reviewed_at: new Date().toISOString() }).eq('id', id)
    refresh()
  }

  if (!admin) {
    return (
      <div>
        <PageHeader title="Suggestions" />
        <div className="card p-6 text-ink/60">Only family admins can review suggestions.</div>
      </div>
    )
  }

  return (
    <div className="max-w-2xl">
      <PageHeader title="Suggestions" subtitle="Review changes proposed by contributors" />
      {isLoading ? (
        <Spinner />
      ) : suggestions.length === 0 ? (
        <EmptyState icon="inbox" title="Nothing to review" body="Contributor suggestions will appear here for your approval." />
      ) : (
        <div className="space-y-4">
          {suggestions.map((s) => {
            const target = s.target_member_id ? members.find((m) => m.id === s.target_member_id) : null
            const fields = Object.entries(s.payload ?? {}).filter(([, v]) => v !== null && v !== '')
            return (
              <div key={s.id} className="card p-5">
                <div className="flex items-center justify-between">
                  <span className="rounded-pill bg-brand-50 text-brand-700 px-3 py-1 text-xs font-bold">
                    {s.kind === 'add_member' ? 'New member' : `Edit ${target ? fullName(target) : 'member'}`}
                  </span>
                </div>
                <dl className="mt-3 grid sm:grid-cols-2 gap-x-6 gap-y-1 text-sm">
                  {fields.map(([k, v]) => (
                    <div key={k} className="flex justify-between border-b border-black/5 py-1">
                      <dt className="text-ink/45 capitalize">{k.replace(/_/g, ' ')}</dt>
                      <dd className="font-medium">{String(v)}</dd>
                    </div>
                  ))}
                </dl>
                {s.note && <p className="mt-3 text-sm text-ink/60 italic">“{s.note}”</p>}
                <div className="mt-4 flex gap-2">
                  <button onClick={() => approve(s.id)} className="btn-primary h-10">Approve</button>
                  <button onClick={() => reject(s.id)} className="btn-ghost h-10">Reject</button>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
