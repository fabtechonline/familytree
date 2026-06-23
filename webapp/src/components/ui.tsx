import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import Icon, { type IconName } from './Icon'

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string
  subtitle?: string
  action?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4 mb-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-ink/60">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

export function Spinner() {
  return (
    <div className="grid place-items-center py-20">
      <div className="h-10 w-10 rounded-full border-4 border-brand/20 border-t-brand animate-spin" />
    </div>
  )
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: IconName
  title: string
  body?: string
  action?: ReactNode
}) {
  return (
    <div className="card p-12 text-center">
      <div className="mx-auto h-14 w-14 rounded-2xl bg-brand-50 text-brand-700 grid place-items-center">
        <Icon name={icon} className="h-7 w-7" />
      </div>
      <h3 className="mt-4 text-lg font-bold">{title}</h3>
      {body && <p className="mt-1 text-sm text-ink/60 max-w-sm mx-auto">{body}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  )
}

export function StatCard({ label, value, icon }: { label: string; value: ReactNode; icon: IconName }) {
  return (
    <div className="card p-5">
      <div className="flex items-center justify-between">
        <span className="text-sm text-ink/55">{label}</span>
        <Icon name={icon} className="h-5 w-5 text-brand" />
      </div>
      <div className="mt-2 text-3xl font-extrabold">{value}</div>
    </div>
  )
}

export function QuickLink({ to, title, body, icon }: { to: string; title: string; body: string; icon: IconName }) {
  return (
    <Link to={to} className="card p-5 hover:shadow-soft transition group">
      <div className="h-11 w-11 rounded-xl bg-brand-50 text-brand-700 grid place-items-center group-hover:bg-brand group-hover:text-white transition">
        <Icon name={icon} className="h-6 w-6" />
      </div>
      <h3 className="mt-3 font-bold">{title}</h3>
      <p className="mt-1 text-sm text-ink/55">{body}</p>
    </Link>
  )
}
