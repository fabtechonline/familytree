import { Link } from 'react-router-dom'
import type { ReactNode } from 'react'

export default function AuthLayout({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string
  subtitle?: string
  children: ReactNode
  footer?: ReactNode
}) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-brand-50 to-canvas">
      <header className="container-x h-16 flex items-center">
        <Link to="/" className="inline-flex items-center gap-2 font-extrabold text-brand-700">
          <img src="/branding/icon_master.png" alt="" className="h-8 w-8 rounded-lg" />
          <span className="text-xl tracking-tight">Riza</span>
        </Link>
      </header>
      <main className="grid place-items-center px-5 py-10">
        <div className="w-full max-w-md">
          <div className="card p-8">
            <h1 className="text-2xl font-extrabold tracking-tight">{title}</h1>
            {subtitle && <p className="mt-1 text-sm text-ink/60">{subtitle}</p>}
            <div className="mt-6">{children}</div>
          </div>
          {footer && <div className="mt-5 text-center text-sm text-ink/60">{footer}</div>}
        </div>
      </main>
    </div>
  )
}
