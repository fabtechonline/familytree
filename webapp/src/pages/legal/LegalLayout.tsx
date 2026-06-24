import { Link } from 'react-router-dom'

/** Shared shell for the public Privacy Policy and Terms pages. */
export default function LegalLayout({
  title,
  updated,
  children,
}: {
  title: string
  updated: string
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen bg-white text-ink">
      <header className="border-b border-black/5">
        <div className="container-x flex items-center justify-between py-4">
          <Link to="/" className="font-extrabold text-brand-700">
            Riza
          </Link>
          <nav className="flex items-center gap-5 text-sm text-ink/60">
            <Link to="/privacy" className="hover:text-brand-700">Privacy</Link>
            <Link to="/terms" className="hover:text-brand-700">Terms</Link>
            <Link to="/" className="hover:text-brand-700">Home</Link>
          </nav>
        </div>
      </header>

      <main className="container-x max-w-3xl py-12">
        <h1 className="text-3xl font-bold">{title}</h1>
        <p className="mt-1 text-sm text-ink/50">Last updated: {updated}</p>
        <div className="legal mt-8 space-y-5 text-[15px] leading-relaxed text-ink/80">
          {children}
        </div>
        <p className="mt-12 border-t border-black/5 pt-6 text-xs text-ink/40">
          © {new Date().getFullYear()} Riza, operated by Farhad Bux (Fabtech Online).
          Questions? <a className="text-brand-700" href="mailto:fabtechonline@gmail.com">fabtechonline@gmail.com</a>
        </p>
      </main>
    </div>
  )
}

/** Section heading used inside legal documents. */
export function H2({ children }: { children: React.ReactNode }) {
  return <h2 className="pt-3 text-lg font-semibold text-ink">{children}</h2>
}
