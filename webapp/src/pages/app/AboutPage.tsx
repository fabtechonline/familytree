import Icon from '../../components/Icon'

const APP_VERSION = '1.0.0'
const DEV_EMAIL = 'fabtechonline@gmail.com'

export default function AboutPage() {
  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold text-ink">About</h1>

      <div className="card mt-6 p-8 text-center">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-brand-50 text-brand-700">
          <Icon name="tree" className="h-9 w-9" />
        </div>
        <div className="mt-3 text-xl font-extrabold text-brand-700">Riza</div>
        <p className="text-sm text-ink/60">Your family, beautifully connected</p>
        <p className="mt-1 text-xs text-ink/50">Version {APP_VERSION}</p>
      </div>

      <h2 className="mt-8 text-sm font-semibold text-ink/70">Developer</h2>
      <div className="card mt-2 divide-y divide-ink/10">
        <div className="flex items-center gap-3 p-4">
          <Icon name="user" className="h-5 w-5 text-ink/50" />
          <div>
            <div className="text-sm font-medium text-ink">Farhad Bux</div>
            <div className="text-xs text-ink/50">Fabtech Online</div>
          </div>
        </div>
        <a
          href={`mailto:${DEV_EMAIL}?subject=${encodeURIComponent('Riza app')}`}
          className="flex items-center gap-3 p-4 hover:bg-brand-50"
        >
          <Icon name="globe" className="h-5 w-5 text-ink/50" />
          <div className="min-w-0">
            <div className="text-sm font-medium text-ink">Contact</div>
            <div className="truncate text-xs text-ink/50">{DEV_EMAIL}</div>
          </div>
        </a>
      </div>

      <p className="mt-6 text-center text-xs text-ink/40">
        © 2026 Farhad Bux. All rights reserved.
      </p>
    </div>
  )
}
