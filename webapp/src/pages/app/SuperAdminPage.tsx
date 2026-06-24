import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { Link, Navigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import {
  useMyProfile, useAnalytics, useAdminFamilies, usePlans, useAppSettings, useFamilyDetail,
  type AdminFamily, type AdminPlan, type AppSetting,
} from '../../data/admin-queries'
import { formatDate } from '../../lib/member-utils'
import { Spinner, StatCard } from '../../components/ui'
import Icon from '../../components/Icon'

const rands = (cents: number) => `R${(cents / 100).toFixed(2).replace(/\.00$/, '')}`
type Tab = 'overview' | 'families' | 'plans' | 'settings'

export default function SuperAdminPage() {
  const qc = useQueryClient()
  const { signOut } = useAuth()
  const { data: profile, isLoading: pLoading } = useMyProfile()
  const isSuper = !!profile?.is_super_admin
  const [tab, setTab] = useState<Tab>('overview')

  if (pLoading) return <div className="min-h-screen grid place-items-center"><Spinner /></div>
  if (!isSuper) return <Navigate to="/app" replace />

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['admin-families'] })
    qc.invalidateQueries({ queryKey: ['admin-analytics'] })
    qc.invalidateQueries({ queryKey: ['admin-family-detail'] })
  }

  return (
    <div className="min-h-screen bg-canvas">
      <header className="border-b border-black/5 bg-white">
        <div className="container-x h-16 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2 font-extrabold text-brand-700">
            <img src="/branding/icon_master.png" alt="" className="h-8 w-8 rounded-lg" />
            <span className="text-xl">Riza</span>
            <span className="ml-2 rounded-pill bg-ink text-white text-xs px-2 py-0.5">admin</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link to="/app" className="btn-ghost h-10">My families</Link>
            <button onClick={signOut} className="btn-ghost h-10"><Icon name="logout" className="h-4 w-4" /> Sign out</button>
          </div>
        </div>
      </header>

      <div className="container-x py-8">
        <h1 className="text-2xl font-bold text-ink">Platform admin</h1>
        <p className="text-sm text-ink/50">Riza super-admin console</p>

        <div className="mt-6 flex gap-1 border-b border-black/5">
          {(['overview', 'families', 'plans', 'settings'] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 text-sm font-medium capitalize border-b-2 -mb-px ${
                tab === t ? 'border-brand-600 text-brand-700' : 'border-transparent text-ink/50 hover:text-ink'
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        <div className="mt-6">
          {tab === 'overview' && <OverviewTab />}
          {tab === 'families' && <FamiliesTab onChange={invalidate} />}
          {tab === 'plans' && <PlansTab onChange={() => qc.invalidateQueries({ queryKey: ['admin-plans'] })} />}
          {tab === 'settings' && <SettingsTab onChange={() => qc.invalidateQueries({ queryKey: ['admin-settings'] })} />}
        </div>
      </div>
    </div>
  )
}

// ---------- Overview ----------
function OverviewTab() {
  const { data: a } = useAnalytics(true)
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="MRR" value={a ? rands(a.mrr_cents) : '—'} icon="chart" />
        <StatCard label="Premium families" value={a?.premium_families ?? '—'} icon="crown" />
        <StatCard label="Families" value={a?.total_families ?? '—'} icon="tree" />
        <StatCard label="Users" value={a?.total_users ?? '—'} icon="members" />
        <StatCard label="New (30d)" value={a?.new_families_30d ?? '—'} icon="plus" />
        <StatCard label="Lifetime" value={a?.lifetime_families ?? '—'} icon="crown" />
        <StatCard label="Comped" value={a?.comp_families ?? '—'} icon="gift" />
        <StatCard label="Suspended" value={a?.suspended_families ?? '—'} icon="shield" />
      </div>
      <div className="card p-6">
        <h2 className="font-bold mb-3">Plan distribution</h2>
        {a ? (
          <div className="flex flex-wrap gap-3 text-sm">
            {Object.entries(a.plan_distribution).map(([k, v]) => (
              <span key={k} className="rounded-pill bg-brand-50 text-brand-700 px-3 py-1">{k}: <b>{v}</b></span>
            ))}
            {Object.keys(a.plan_distribution).length === 0 && <span className="text-ink/40">No billing rows yet.</span>}
          </div>
        ) : <Spinner />}
      </div>
    </div>
  )
}

// ---------- Families ----------
function FamiliesTab({ onChange }: { onChange: () => void }) {
  const { data: families = [], isLoading } = useAdminFamilies(true)
  const [selected, setSelected] = useState<AdminFamily | null>(null)
  return (
    <div className="grid lg:grid-cols-2 gap-6">
      <div className="card p-6">
        <h2 className="font-bold mb-4">Families</h2>
        {isLoading ? <Spinner /> : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-ink/45 border-b border-black/5">
                <tr><th className="py-2 pr-3 font-medium">Family</th><th className="py-2 pr-3 font-medium">Plan</th><th className="py-2 pr-3 font-medium">Members</th><th className="py-2 pr-3 font-medium">Status</th></tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                {families.map((f) => (
                  <tr key={f.id} onClick={() => setSelected(f)} className={`cursor-pointer hover:bg-brand-50 ${selected?.id === f.id ? 'bg-brand-50' : ''}`}>
                    <td className="py-3 pr-3 font-medium">{f.name}</td>
                    <td className="py-3 pr-3"><span className="capitalize">{f.plan_key.replace('_', ' ')}</span>{f.is_comp && <span className="ml-1 text-xs text-sun">comp</span>}</td>
                    <td className="py-3 pr-3">{f.person_count}</td>
                    <td className="py-3 pr-3">{f.is_suspended ? <span className="text-coral font-medium">suspended</span> : <span className="capitalize text-ink/60">{f.subscription_tier}</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      <div>{selected ? <FamilyDetail family={selected} onChange={onChange} /> : <div className="card p-6 text-sm text-ink/40">Select a family to manage its plan, limit, suspension and payment history.</div>}</div>
    </div>
  )
}

function FamilyDetail({ family, onChange }: { family: AdminFamily; onChange: () => void }) {
  const qc = useQueryClient()
  const { data: detail } = useFamilyDetail(family.id)
  const { data: plans = [] } = usePlans(true)
  const [plan, setPlan] = useState(family.plan_key)
  const [comp, setComp] = useState(family.is_comp)
  const [expires, setExpires] = useState('')
  const [limit, setLimit] = useState('')
  const [busy, setBusy] = useState(false)

  const refresh = () => { qc.invalidateQueries({ queryKey: ['admin-family-detail', family.id] }); onChange() }
  const run = async (fn: () => PromiseLike<{ error: { message: string } | null }>) => {
    setBusy(true)
    const { error } = await fn()
    setBusy(false)
    if (error) return alert(error.message)
    refresh()
  }

  const applyPlan = () => run(() => supabase.rpc('admin_set_family_plan', {
    p_family: family.id, p_plan_key: plan, p_comp: comp,
    p_expires_at: expires ? new Date(expires).toISOString() : null,
  }))
  const toggleSuspend = () => {
    const reason = family.is_suspended ? null : (prompt('Reason for suspension (optional):') ?? '')
    return run(() => supabase.rpc('admin_suspend_family', { p_family: family.id, p_reason: reason, p_suspend: !family.is_suspended }))
  }
  const saveLimit = () => run(() => supabase.rpc('admin_set_member_limit', { p_family: family.id, p_limit: limit === '' ? null : Number(limit) }))

  return (
    <div className="card p-6 space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="font-bold">{family.name}</h2>
        <button onClick={toggleSuspend} disabled={busy} className={family.is_suspended ? 'btn-primary h-9' : 'btn-ghost h-9 text-coral'}>
          {family.is_suspended ? 'Unsuspend' : 'Suspend access'}
        </button>
      </div>
      <div className="text-sm text-ink/50">{family.member_count} members · {family.person_count} people · created {formatDate(family.created_at)}</div>

      <div className="border-t border-black/5 pt-4">
        <h3 className="font-semibold text-sm mb-2">Plan</h3>
        <div className="flex flex-wrap items-end gap-3">
          <label className="text-sm">Plan<br/>
            <select value={plan} onChange={(e) => setPlan(e.target.value)} className="mt-1 rounded-lg border border-black/10 px-2 py-1.5">
              {plans.map((p) => <option key={p.key} value={p.key}>{p.label}</option>)}
            </select>
          </label>
          <label className="text-sm">Expires (optional)<br/>
            <input type="date" value={expires} onChange={(e) => setExpires(e.target.value)} className="mt-1 rounded-lg border border-black/10 px-2 py-1.5" />
          </label>
          <label className="text-sm flex items-center gap-2"><input type="checkbox" checked={comp} onChange={(e) => setComp(e.target.checked)} /> Free / comp</label>
          <button onClick={applyPlan} disabled={busy} className="btn-primary h-9">Apply plan</button>
        </div>
        <p className="mt-1 text-xs text-ink/40">"Free / comp" grants a paid plan at no charge. Leave expiry blank for open-ended (lifetime never expires).</p>
      </div>

      <div className="border-t border-black/5 pt-4">
        <h3 className="font-semibold text-sm mb-2">Free-tier member limit</h3>
        <div className="flex items-end gap-3">
          <input type="number" placeholder="default" value={limit} onChange={(e) => setLimit(e.target.value)} className="rounded-lg border border-black/10 px-2 py-1.5 w-28" />
          <button onClick={saveLimit} disabled={busy} className="btn-ghost h-9">Save limit</button>
        </div>
        <p className="mt-1 text-xs text-ink/40">Override for this family only; blank = use the global default.</p>
      </div>

      <div className="border-t border-black/5 pt-4">
        <h3 className="font-semibold text-sm mb-2">Payment history</h3>
        {!detail ? <Spinner /> : detail.events.length === 0 ? (
          <p className="text-sm text-ink/40">No payment events yet.</p>
        ) : (
          <ul className="text-sm space-y-1">
            {detail.events.map((e, i) => (
              <li key={i} className="flex justify-between"><span className="text-ink/60">{String(e.provider)} · {String(e.event_type)}</span><span>{e.amount_cents ? rands(Number(e.amount_cents)) : ''}</span></li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}

// ---------- Plans ----------
function PlansTab({ onChange }: { onChange: () => void }) {
  const { data: plans = [], isLoading } = usePlans(true)
  if (isLoading) return <Spinner />
  return (
    <div className="space-y-4">
      <p className="text-sm text-ink/50">Edit the fixed tiers. Prices in Rands. Member limits &amp; feature toggles live under <b>Settings</b>. Native-store SKUs (Play/Apple) must also match these product IDs.</p>
      {plans.map((p) => <PlanRow key={p.key} plan={p} onChange={onChange} />)}
    </div>
  )
}

function PlanRow({ plan, onChange }: { plan: AdminPlan; onChange: () => void }) {
  const [label, setLabel] = useState(plan.label)
  const [price, setPrice] = useState((plan.price_cents / 100).toString())
  const [active, setActive] = useState(plan.is_active)
  const [paystack, setPaystack] = useState(plan.paystack_plan_code ?? '')
  const [sku, setSku] = useState(plan.store_product_id ?? '')
  const [busy, setBusy] = useState(false)

  const save = async () => {
    setBusy(true)
    const { error } = await supabase.rpc('admin_update_plan', {
      p_key: plan.key, p_label: label, p_price_cents: Math.round(Number(price) * 100),
      p_interval: plan.interval, p_is_active: active,
      p_paystack_plan_code: paystack || null, p_store_product_id: sku || null,
    })
    setBusy(false)
    if (error) return alert(error.message)
    onChange()
  }

  return (
    <div className="card p-5">
      <div className="flex items-center justify-between mb-3">
        <div className="font-semibold capitalize">{plan.key.replace('_', ' ')} <span className="text-xs text-ink/40">({plan.tier} · {plan.interval})</span></div>
        <label className="text-sm flex items-center gap-2"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Active</label>
      </div>
      <div className="grid sm:grid-cols-2 gap-3 text-sm">
        <label>Label<input value={label} onChange={(e) => setLabel(e.target.value)} className="mt-1 w-full rounded-lg border border-black/10 px-2 py-1.5" /></label>
        <label>Price (R)<input type="number" value={price} onChange={(e) => setPrice(e.target.value)} className="mt-1 w-full rounded-lg border border-black/10 px-2 py-1.5" /></label>
        <label>Paystack plan code<input value={paystack} onChange={(e) => setPaystack(e.target.value)} placeholder="PLN_..." className="mt-1 w-full rounded-lg border border-black/10 px-2 py-1.5" /></label>
        <label>Store product ID<input value={sku} onChange={(e) => setSku(e.target.value)} placeholder="premium_monthly" className="mt-1 w-full rounded-lg border border-black/10 px-2 py-1.5" /></label>
      </div>
      <div className="mt-3 text-right"><button onClick={save} disabled={busy} className="btn-primary h-9">Save</button></div>
    </div>
  )
}

// ---------- Settings ----------
function SettingsTab({ onChange }: { onChange: () => void }) {
  const { data: settings = [], isLoading } = useAppSettings(true)
  if (isLoading) return <Spinner />
  const get = (k: string) => settings.find((s) => s.key === k)
  const save = async (key: string, value: unknown) => {
    const { error } = await supabase.rpc('admin_set_setting', { p_key: key, p_value: value })
    if (error) return alert(error.message)
    onChange()
  }
  return (
    <div className="space-y-4 max-w-2xl">
      <SettingCard title="Paystack" setting={get('paystack')} fields={[
        { k: 'public_key', label: 'Public key', placeholder: 'pk_test_...' },
        { k: 'mode', label: 'Mode (test / live)', placeholder: 'test' },
      ]} note="The secret key is never stored here — it stays a server-side function secret." onSave={(v) => save('paystack', v)} />

      <SettingCard title="Support & announcements" setting={get('support')} fields={[
        { k: 'email', label: 'Support email' },
        { k: 'announcement', label: 'Announcement banner (blank = hidden)' },
      ]} onSave={(v) => save('support', v)} />

      <SettingCard title="Maintenance mode" setting={get('maintenance')} fields={[
        { k: 'enabled', label: 'Enabled (true / false)' },
        { k: 'message', label: 'Message' },
      ]} onSave={(v) => save('maintenance', v)} />

      <FeaturesCard setting={get('features')} onSave={(v) => save('features', v)} />
      <LimitCard setting={get('free_member_limit')} onSave={(v) => save('free_member_limit', v)} />
    </div>
  )
}

function SettingCard({ title, setting, fields, note, onSave }: {
  title: string; setting?: AppSetting; note?: string
  fields: Array<{ k: string; label: string; placeholder?: string }>
  onSave: (v: Record<string, unknown>) => void
}) {
  const initial = (setting?.value ?? {}) as Record<string, unknown>
  const [vals, setVals] = useState<Record<string, string>>(() =>
    Object.fromEntries(fields.map((f) => [f.k, String(initial[f.k] ?? '')])))
  const save = () => {
    const out: Record<string, unknown> = {}
    for (const f of fields) {
      const raw = vals[f.k]
      out[f.k] = raw === 'true' ? true : raw === 'false' ? false : raw
    }
    onSave(out)
  }
  return (
    <div className="card p-5">
      <h3 className="font-semibold mb-3">{title}</h3>
      <div className="space-y-3 text-sm">
        {fields.map((f) => (
          <label key={f.k} className="block">{f.label}
            <input value={vals[f.k]} placeholder={f.placeholder} onChange={(e) => setVals({ ...vals, [f.k]: e.target.value })} className="mt-1 w-full rounded-lg border border-black/10 px-2 py-1.5" />
          </label>
        ))}
      </div>
      {note && <p className="mt-2 text-xs text-ink/40">{note}</p>}
      <div className="mt-3 text-right"><button onClick={save} className="btn-primary h-9">Save</button></div>
    </div>
  )
}

function FeaturesCard({ setting, onSave }: { setting?: AppSetting; onSave: (v: Record<string, boolean>) => void }) {
  const initial = (setting?.value ?? {}) as Record<string, boolean>
  const keys = ['face_recognition', 'ai_avatar', 'data_export']
  const [vals, setVals] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(keys.map((k) => [k, !!initial[k]])))
  return (
    <div className="card p-5">
      <h3 className="font-semibold mb-3">Premium feature flags</h3>
      <div className="space-y-2 text-sm">
        {keys.map((k) => (
          <label key={k} className="flex items-center gap-2 capitalize">
            <input type="checkbox" checked={vals[k]} onChange={(e) => setVals({ ...vals, [k]: e.target.checked })} /> {k.replace('_', ' ')}
          </label>
        ))}
      </div>
      <div className="mt-3 text-right"><button onClick={() => onSave(vals)} className="btn-primary h-9">Save</button></div>
    </div>
  )
}

function LimitCard({ setting, onSave }: { setting?: AppSetting; onSave: (v: number) => void }) {
  const [limit, setLimit] = useState(String((setting?.value as number) ?? 50))
  return (
    <div className="card p-5">
      <h3 className="font-semibold mb-2">Default free-tier member limit</h3>
      <div className="flex items-end gap-3">
        <input type="number" value={limit} onChange={(e) => setLimit(e.target.value)} className="rounded-lg border border-black/10 px-2 py-1.5 w-32" />
        <button onClick={() => onSave(Number(limit))} className="btn-primary h-9">Save</button>
      </div>
      <p className="mt-1 text-xs text-ink/40">Applies to all free families without a per-family override.</p>
    </div>
  )
}
