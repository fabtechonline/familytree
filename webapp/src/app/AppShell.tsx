import { useState } from 'react'
import { NavLink, Navigate, Outlet, useNavigate } from 'react-router-dom'
import Icon, { type IconName } from '../components/Icon'
import { useAuth } from '../auth/AuthProvider'
import { useFamily } from './FamilyProvider'
import { isAdmin } from '../lib/types'
import { Spinner } from '../components/ui'
import { useMyProfile } from '../data/admin-queries'
import { useRealtime } from './useRealtime'

interface NavItem {
  to: string
  label: string
  icon: IconName
  adminOnly?: boolean
  superOnly?: boolean
}

const NAV: NavItem[] = [
  { to: '/app', label: 'Dashboard', icon: 'dashboard' },
  { to: '/app/tree', label: 'Family tree', icon: 'tree' },
  { to: '/app/map', label: 'Family map', icon: 'map' },
  { to: '/app/members', label: 'Members', icon: 'members' },
  { to: '/app/feed', label: 'Feed', icon: 'feed' },
  { to: '/app/celebrations', label: 'Celebrations', icon: 'gift' },
  { to: '/app/relate', label: 'How related?', icon: 'link' },
  { to: '/app/insights', label: 'Family DNA', icon: 'chart' },
  { to: '/app/timemachine', label: 'Time machine', icon: 'clock' },
  { to: '/app/capsules', label: 'Capsules', icon: 'capsule' },
  { to: '/app/invite', label: 'Invite & roles', icon: 'invite' },
  { to: '/app/suggestions', label: 'Suggestions', icon: 'inbox', adminOnly: true },
  { to: '/app/admin', label: 'Platform admin', icon: 'shield', superOnly: true },
]

function FamilySwitcher() {
  const { families, current, setCurrentId } = useFamily()
  const [open, setOpen] = useState(false)
  if (!current) return null
  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center gap-3 rounded-xl border border-black/10 bg-white px-3 py-2.5 text-left hover:border-brand/40"
      >
        <div className="h-8 w-8 rounded-lg bg-brand text-white grid place-items-center font-bold text-sm">
          {current.name[0]}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-semibold">{current.name}</div>
          <div className="text-[11px] text-ink/50 capitalize">{current.myRole}</div>
        </div>
        <Icon name="chevron" className="h-4 w-4 text-ink/40" />
      </button>
      {open && (
        <div className="absolute z-30 mt-1 w-full rounded-xl border border-black/10 bg-white shadow-soft overflow-hidden">
          {families.map((f) => (
            <button
              key={f.id}
              onClick={() => {
                setCurrentId(f.id)
                setOpen(false)
              }}
              className={`w-full flex items-center gap-2 px-3 py-2.5 text-left text-sm hover:bg-brand-50 ${
                f.id === current.id ? 'bg-brand-50 font-semibold' : ''
              }`}
            >
              <div className="h-6 w-6 rounded-md bg-brand/80 text-white grid place-items-center text-xs font-bold">
                {f.name[0]}
              </div>
              <span className="truncate">{f.name}</span>
            </button>
          ))}
          <NavLink
            to="/app/create-family"
            onClick={() => setOpen(false)}
            className="w-full flex items-center gap-2 px-3 py-2.5 text-left text-sm text-brand-700 hover:bg-brand-50 border-t border-black/5"
          >
            <Icon name="plus" className="h-4 w-4" /> New family
          </NavLink>
        </div>
      )}
    </div>
  )
}

export default function AppShell() {
  const { signOut } = useAuth()
  const { current, families, loading } = useFamily()
  const { data: profile } = useMyProfile()
  const nav = useNavigate()
  const [mobileOpen, setMobileOpen] = useState(false)
  const admin = isAdmin(current?.myRole)
  const isSuper = !!profile?.is_super_admin

  useRealtime(current?.id)

  // Onboarding gate: a signed-in user with no family creates one first — except
  // a super-admin, who still needs the console, so send them there instead of
  // trapping them on the create-family screen.
  if (loading) return <Spinner />
  if (families.length === 0)
    return <Navigate to={isSuper ? '/app/admin' : '/app/create-family'} replace />

  const items = NAV.filter((n) => (!n.adminOnly || admin) && (!n.superOnly || isSuper))

  const handleSignOut = async () => {
    await signOut()
    nav('/', { replace: true })
  }

  const sidebar = (
    <div className="flex h-full flex-col gap-4 p-4">
      <NavLink to="/app" className="flex items-center gap-2 px-2 font-extrabold text-brand-700">
        <img src="/branding/icon_master.png" alt="" className="h-8 w-8 rounded-lg" />
        <span className="text-xl tracking-tight">Riza</span>
      </NavLink>
      <FamilySwitcher />
      <nav className="flex-1 space-y-1 overflow-y-auto">
        {items.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/app'}
            onClick={() => setMobileOpen(false)}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                isActive ? 'bg-brand text-white shadow-soft' : 'text-ink/70 hover:bg-brand-50'
              }`
            }
          >
            <Icon name={item.icon} className="h-5 w-5" />
            {item.label}
          </NavLink>
        ))}
      </nav>
      <NavLink
        to="/app/account"
        onClick={() => setMobileOpen(false)}
        className={({ isActive }) =>
          `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium ${isActive ? 'bg-brand-50 text-brand-700' : 'text-ink/60 hover:bg-brand-50'}`
        }
      >
        <Icon name="user" className="h-5 w-5" /> Account
      </NavLink>
      <NavLink
        to="/app/about"
        onClick={() => setMobileOpen(false)}
        className={({ isActive }) =>
          `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium ${isActive ? 'bg-brand-50 text-brand-700' : 'text-ink/60 hover:bg-brand-50'}`
        }
      >
        <Icon name="info" className="h-5 w-5" /> About
      </NavLink>
      <button
        onClick={handleSignOut}
        className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-ink/60 hover:bg-coral/10 hover:text-coral"
      >
        <Icon name="logout" className="h-5 w-5" /> Sign out
      </button>
    </div>
  )

  return (
    <div className="min-h-screen bg-canvas">
      {/* Desktop sidebar */}
      <aside className="hidden lg:flex fixed inset-y-0 left-0 w-64 border-r border-black/5 bg-white">
        {sidebar}
      </aside>

      {/* Mobile top bar */}
      <div className="lg:hidden sticky top-0 z-40 flex items-center justify-between border-b border-black/5 bg-white px-4 h-14">
        <NavLink to="/app" className="flex items-center gap-2 font-extrabold text-brand-700">
          <img src="/branding/icon_master.png" alt="" className="h-7 w-7 rounded-lg" />
          <span className="text-lg">Riza</span>
        </NavLink>
        <button onClick={() => setMobileOpen(true)} className="p-2 -mr-2">
          <Icon name="members" className="h-6 w-6" />
        </button>
      </div>
      {mobileOpen && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div className="w-72 bg-white shadow-xl">{sidebar}</div>
          <div className="flex-1 bg-black/30" onClick={() => setMobileOpen(false)} />
        </div>
      )}

      <main className="lg:pl-64">
        <div className="container-x py-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
