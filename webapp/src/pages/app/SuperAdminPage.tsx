import { useQueryClient } from '@tanstack/react-query'
import { Link, Navigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { useMyProfile, usePlatformStats, useAdminFamilies } from '../../data/admin-queries'
import type { SubscriptionTier } from '../../lib/types'
import { formatDate } from '../../lib/member-utils'
import { PageHeader, Spinner, StatCard } from '../../components/ui'
import Icon from '../../components/Icon'

export default function SuperAdminPage() {
  const qc = useQueryClient()
  const { signOut } = useAuth()
  const { data: profile, isLoading: pLoading } = useMyProfile()
  const isSuper = !!profile?.is_super_admin
  const { data: stats } = usePlatformStats(isSuper)
  const { data: families = [], isLoading } = useAdminFamilies(isSuper)

  if (pLoading) return <div className="min-h-screen grid place-items-center"><Spinner /></div>
  if (!isSuper) return <Navigate to="/app" replace />

  const setTier = async (familyId: string, tier: SubscriptionTier) => {
    const { error } = await supabase.rpc('admin_set_subscription', { p_family: familyId, p_tier: tier })
    if (error) return alert(error.message)
    qc.invalidateQueries({ queryKey: ['admin-families'] })
    qc.invalidateQueries({ queryKey: ['platform-stats'] })
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
      <PageHeader title="Platform admin" subtitle="Riza super-admin console" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="Users" value={stats?.total_users ?? '—'} icon="members" />
        <StatCard label="Families" value={stats?.total_families ?? '—'} icon="tree" />
        <StatCard label="Premium" value={stats?.premium_families ?? '—'} icon="crown" />
        <StatCard label="Blocked" value={stats?.blocked_users ?? '—'} icon="shield" />
      </div>

      <div className="card p-6 mt-6">
        <h2 className="font-bold mb-4">Families</h2>
        {isLoading ? (
          <Spinner />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-ink/45 border-b border-black/5">
                <tr>
                  <th className="py-2 pr-4 font-medium">Family</th>
                  <th className="py-2 pr-4 font-medium">Members</th>
                  <th className="py-2 pr-4 font-medium">People</th>
                  <th className="py-2 pr-4 font-medium">Created</th>
                  <th className="py-2 pr-4 font-medium">Tier</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                {families.map((f) => (
                  <tr key={f.id}>
                    <td className="py-3 pr-4 font-medium">{f.name}</td>
                    <td className="py-3 pr-4">{f.member_count}</td>
                    <td className="py-3 pr-4">{f.person_count}</td>
                    <td className="py-3 pr-4 text-ink/50">{formatDate(f.created_at)}</td>
                    <td className="py-3 pr-4">
                      <select
                        value={f.subscription_tier}
                        onChange={(e) => setTier(f.id, e.target.value as SubscriptionTier)}
                        className="rounded-lg border border-black/10 px-2 py-1 capitalize"
                      >
                        <option value="free">Free</option>
                        <option value="premium">Premium</option>
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      </div>
    </div>
  )
}
