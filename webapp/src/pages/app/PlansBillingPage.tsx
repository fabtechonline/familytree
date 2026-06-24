import { useEffect, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useFamily } from '../../app/FamilyProvider'
import { usePlans } from '../../data/admin-queries'
import { supabase } from '../../lib/supabase'
import { startCheckout, cancelSubscription } from '../../lib/billing'
import { isAdmin } from '../../lib/types'
import { Spinner } from '../../components/ui'

const rands = (c: number) => `R${(c / 100).toFixed(2).replace(/\.00$/, '')}`

interface Billing {
  plan_key: string
  status: string
  billing_provider: string
  current_period_end: string | null
  cancel_at_period_end: boolean
  is_comp: boolean
}

export default function PlansBillingPage() {
  const { current } = useFamily()
  const qc = useQueryClient()
  const admin = isAdmin(current?.myRole)
  const { data: plans = [] } = usePlans(!!current)
  const { data: billing } = useQuery({
    queryKey: ['family-billing', current?.id],
    enabled: !!current,
    queryFn: async (): Promise<Billing | null> => {
      const { data } = await supabase.from('family_billing').select('*').eq('family_id', current!.id).maybeSingle()
      return data as Billing | null
    },
  })
  const [busy, setBusy] = useState<string | null>(null)

  // Returning from Paystack: give the webhook a moment, then refresh.
  useEffect(() => {
    if (!current || !new URLSearchParams(location.search).get('ref')) return
    const t = setTimeout(() => {
      qc.invalidateQueries({ queryKey: ['family-billing', current.id] })
      qc.invalidateQueries({ queryKey: ['my-families'] })
    }, 1500)
    return () => clearTimeout(t)
  }, [current, qc])

  if (!current) return <Spinner />
  const premiumPlans = plans.filter((p) => p.tier === 'premium' && p.is_active)
  const canCancel = admin && billing?.billing_provider === 'paystack' &&
    billing?.plan_key !== 'lifetime' && !billing?.cancel_at_period_end &&
    (billing?.status === 'active' || billing?.status === 'non_renewing')

  const upgrade = async (key: string) => {
    setBusy(key)
    try {
      const { authorization_url } = await startCheckout(current.id, key)
      location.href = authorization_url
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Could not start checkout')
      setBusy(null)
    }
  }
  const cancel = async () => {
    if (!confirm('Cancel auto-renewal? You keep Premium until the current period ends.')) return
    setBusy('cancel')
    try {
      await cancelSubscription(current.id)
      qc.invalidateQueries({ queryKey: ['family-billing', current.id] })
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Could not cancel')
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-bold text-ink">Plans &amp; billing</h1>
      <p className="mt-1 text-sm text-ink/60">
        Current plan: <b className="capitalize">{(billing?.plan_key ?? current.subscription_tier).replace('_', ' ')}</b>
        {billing?.is_comp && ' · complimentary'}
        {billing?.current_period_end && ` · renews ${new Date(billing.current_period_end).toLocaleDateString()}`}
        {billing?.cancel_at_period_end && ' · cancels at period end'}
      </p>

      {!admin && (
        <div className="card mt-6 p-6 text-sm text-ink/60">Only the family admin can change the plan.</div>
      )}

      {admin && (
        <>
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            {premiumPlans.map((p) => (
              <div key={p.key} className="card flex flex-col p-6">
                <div className="font-bold">{p.label}</div>
                <div className="mt-2 text-2xl font-extrabold">
                  {rands(p.price_cents)}
                  <span className="text-sm font-normal text-ink/50">{p.interval === 'month' ? '/mo' : p.interval === 'year' ? '/yr' : ''}</span>
                </div>
                <button
                  disabled={!!busy || billing?.plan_key === p.key}
                  onClick={() => upgrade(p.key)}
                  className="btn-primary mt-4 disabled:opacity-60"
                >
                  {busy === p.key ? '…' : billing?.plan_key === p.key ? 'Current plan' : 'Choose'}
                </button>
              </div>
            ))}
          </div>

          {canCancel && (
            <button onClick={cancel} disabled={!!busy} className="btn-ghost mt-6 text-coral">Cancel subscription</button>
          )}

          <p className="mt-6 text-xs text-ink/40">
            Payments are processed securely by Paystack. See our{' '}
            <a className="text-brand-700" href="/cancellation">cancellation policy</a>.
          </p>
        </>
      )}
    </div>
  )
}
