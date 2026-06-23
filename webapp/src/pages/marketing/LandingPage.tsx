import { Link } from 'react-router-dom'
import { useState } from 'react'

/* ------------------------------------------------------------------ icons */
type IconProps = { className?: string }
const Icon = ({ path, className }: IconProps & { path: string }) => (
  <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
    <path d={path} stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)
const I = {
  tree: 'M12 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Zm0 6v4m0 0H7a2 2 0 0 0-2 2v2m9-4h5a2 2 0 0 1 2 2v2M3 19a2 2 0 1 0 4 0 2 2 0 0 0-4 0Zm14 0a2 2 0 1 0 4 0 2 2 0 0 0-4 0Z',
  feed: 'M4 6h16M4 12h16M4 18h10',
  gift: 'M20 12v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8M2 7h20v5H2zM12 7v14M12 7S9 2 6.5 4.5 12 7 12 7Zm0 0s3-5 5.5-2.5S12 7 12 7Z',
  link: 'M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1m-1 8a5 5 0 0 1-7 0 5 5 0 0 1 0-7l2-2a5 5 0 0 1 7 0l1 1',
  chart: 'M4 19V5m0 14h16M8 17v-5m4 5V9m4 8v-7',
  clock: 'M12 7v5l3 2m6-2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  capsule: 'M9 3h6m-3 0v4m-5 0h10l-1 12a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2L7 7Z',
  face: 'M9 9h.01M15 9h.01M9 15a4 4 0 0 0 6 0M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3Z',
  users: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm14 10v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11',
  check: 'M20 6 9 17l-5-5',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
}

const Logo = ({ className = '' }: IconProps) => (
  <span className={`inline-flex items-center gap-2 font-extrabold ${className}`}>
    <img src="/branding/icon_master.png" alt="" className="h-8 w-8 rounded-lg" />
    <span className="text-xl tracking-tight">Riza</span>
  </span>
)

/* ------------------------------------------------------------------- data */
const FEATURES = [
  { icon: I.tree, title: 'Living family tree', body: 'A beautiful, pan-and-zoom tree that grows with your family. Tap any relative to see their story, photos, and connections.' },
  { icon: I.feed, title: 'Private family feed', body: 'Share births, weddings, graduations and everyday news in a space only your family can see — no public timelines.' },
  { icon: I.gift, title: 'Never miss a celebration', body: 'Birthdays and anniversaries surface automatically, with one-tap greeting cards for the people who matter.' },
  { icon: I.link, title: '“How am I related?”', body: 'Pick any two people and Riza spells out the exact kinship — second cousins, great-aunts and all.' },
  { icon: I.chart, title: 'Family insights', body: 'See your family’s DNA: total people, generations spanned, and the surnames that thread through your history.' },
  { icon: I.clock, title: 'Time machine', body: 'Scrub through the years and watch your family tree grow, branch by branch, generation by generation.' },
  { icon: I.capsule, title: 'Legacy capsules', body: 'Seal messages to be opened on a future date — a note to a grandchild, a memory for an anniversary yet to come.' },
  { icon: I.face, title: 'Point & Recognise', body: 'On the mobile app, point your camera at a relative and Riza recognises them from your tree. (Premium)' },
]

const STEPS = [
  { n: '1', title: 'Create your family', body: 'Sign up in seconds and start your private family space. You’re the admin.' },
  { n: '2', title: 'Build the tree', body: 'Add relatives, link parents, partners and children, and upload their photos.' },
  { n: '3', title: 'Invite everyone', body: 'Share a code or QR. Family members join with the right role — from viewer to editor.' },
  { n: '4', title: 'Grow together', body: 'Celebrate, share memories, and watch your living history take shape over time.' },
]

const FAQS = [
  { q: 'Is my family’s data private?', a: 'Yes. Every family is a private, isolated space. Only people you invite can see your tree, feed, and memories — there are no public profiles, and access is enforced at the database level by row-level security.' },
  { q: 'Do I need the mobile app?', a: 'No — Riza works in your browser with all the core features. The mobile apps add camera-based extras like Point & Recognise and on-device photo capture.' },
  { q: 'Can the whole family contribute?', a: 'Absolutely. Assign roles: admins manage everything, editors add and edit relatives, contributors suggest changes for approval, and relatives can claim and edit just their own profile.' },
  { q: 'What does Premium add?', a: 'Premium unlocks Point & Recognise — on-device face recognition that identifies relatives through your phone camera. All tree-building, feed, celebrations and insights are free.' },
  { q: 'Can I move between families?', a: 'Yes. You can belong to more than one family and switch between them, each with its own tree and its own role for you.' },
]

/* -------------------------------------------------------------- sections */
function Nav() {
  return (
    <header className="sticky top-0 z-40 backdrop-blur bg-canvas/80 border-b border-black/5">
      <nav className="container-x flex items-center justify-between h-16">
        <Logo className="text-brand-700" />
        <div className="hidden md:flex items-center gap-8 text-sm font-medium text-ink/70">
          <a href="#features" className="hover:text-brand-700">Features</a>
          <a href="#how" className="hover:text-brand-700">How it works</a>
          <a href="#pricing" className="hover:text-brand-700">Pricing</a>
          <a href="#faq" className="hover:text-brand-700">FAQ</a>
        </div>
        <div className="flex items-center gap-3">
          <Link to="/app/sign-in" className="hidden sm:inline-flex btn-ghost h-10 px-4">Log in</Link>
          <Link to="/app/register" className="btn-primary h-10 px-5">Get started</Link>
        </div>
      </nav>
    </header>
  )
}

function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div className="absolute inset-0 -z-10 bg-gradient-to-b from-brand-50 to-canvas" />
      <div className="absolute -top-24 -right-24 -z-10 h-96 w-96 rounded-full bg-brand-200/40 blur-3xl" />
      <div className="container-x py-20 sm:py-28 grid lg:grid-cols-2 gap-12 items-center">
        <div>
          <span className="inline-flex items-center gap-2 rounded-pill bg-white border border-black/5 px-3 py-1 text-xs font-semibold text-brand-700 shadow-card">
            <Icon path={I.shield} className="h-4 w-4" /> Private by design
          </span>
          <h1 className="mt-5 text-4xl sm:text-6xl font-extrabold tracking-tight leading-[1.05]">
            Your family’s story,<br />
            <span className="text-brand">beautifully connected.</span>
          </h1>
          <p className="mt-5 text-lg text-ink/70 max-w-xl">
            Riza is a private, collaborative family tree. Build your living history together,
            celebrate every milestone, and keep your family close — wherever they are.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link to="/app/register" className="btn-primary">
              Start your family tree <Icon path={I.arrow} className="h-5 w-5" />
            </Link>
            <a href="#features" className="btn-ghost">See what’s inside</a>
          </div>
          <p className="mt-4 text-sm text-ink/50">Free to start · No credit card · Invite your whole family</p>
        </div>
        <div className="relative">
          <div className="card p-6 shadow-soft">
            <div className="flex items-center gap-3 border-b border-black/5 pb-4">
              <img src="/branding/icon_master.png" className="h-10 w-10 rounded-xl" alt="" />
              <div>
                <div className="font-bold">The Bux Family</div>
                <div className="text-xs text-ink/50">4 generations · 38 people</div>
              </div>
            </div>
            <div className="grid grid-cols-3 gap-3 py-6">
              {['Grandpa', 'Grandma', 'Uncle Sam', 'Mum', 'Dad', 'You', 'Sister', 'Cousin', 'Baby'].map((n, idx) => (
                <div key={n} className="flex flex-col items-center gap-2">
                  <div className={`h-12 w-12 rounded-full grid place-items-center text-white font-bold ${idx % 3 === 0 ? 'bg-brand' : idx % 3 === 1 ? 'bg-sky' : 'bg-coral'}`}>
                    {n[0]}
                  </div>
                  <span className="text-[11px] text-ink/60">{n}</span>
                </div>
              ))}
            </div>
            <div className="flex items-center justify-between rounded-xl bg-brand-50 px-4 py-3">
              <span className="text-sm font-medium text-brand-800">🎂 3 birthdays this week</span>
              <span className="text-xs font-semibold text-brand-700">View →</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Features() {
  return (
    <section id="features" className="py-20 sm:py-28">
      <div className="container-x">
        <div className="max-w-2xl">
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Everything your family needs in one place</h2>
          <p className="mt-4 text-lg text-ink/70">From the big branches to the everyday moments — Riza keeps it all connected and private.</p>
        </div>
        <div className="mt-12 grid sm:grid-cols-2 lg:grid-cols-4 gap-5">
          {FEATURES.map((f) => (
            <div key={f.title} className="card p-6 hover:shadow-soft transition">
              <div className="h-11 w-11 rounded-xl bg-brand-50 text-brand-700 grid place-items-center">
                <Icon path={f.icon} className="h-6 w-6" />
              </div>
              <h3 className="mt-4 font-bold">{f.title}</h3>
              <p className="mt-2 text-sm text-ink/60 leading-relaxed">{f.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function HowItWorks() {
  return (
    <section id="how" className="py-20 sm:py-28 bg-white border-y border-black/5">
      <div className="container-x">
        <div className="max-w-2xl">
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Up and running in minutes</h2>
          <p className="mt-4 text-lg text-ink/70">No genealogy degree required. Start small and let your family fill in the rest.</p>
        </div>
        <div className="mt-12 grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {STEPS.map((s) => (
            <div key={s.n} className="relative">
              <div className="h-12 w-12 rounded-2xl bg-brand text-white grid place-items-center text-lg font-extrabold shadow-soft">{s.n}</div>
              <h3 className="mt-4 font-bold">{s.title}</h3>
              <p className="mt-2 text-sm text-ink/60 leading-relaxed">{s.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function Pricing() {
  const free = ['Family tree builder', 'Unlimited relatives & photos', 'Private family feed', 'Birthdays & anniversaries', 'Relationship finder & insights', 'Time machine & legacy capsules', 'Invite your whole family']
  const premium = ['Everything in Free', 'Point & Recognise (camera face ID)', 'Priority support']
  return (
    <section id="pricing" className="py-20 sm:py-28">
      <div className="container-x">
        <div className="max-w-2xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Simple, family-friendly pricing</h2>
          <p className="mt-4 text-lg text-ink/70">Start free. Upgrade only if you want the camera magic.</p>
        </div>
        <div className="mt-12 grid md:grid-cols-2 gap-6 max-w-4xl mx-auto">
          <div className="card p-8">
            <h3 className="font-bold text-lg">Free</h3>
            <div className="mt-2 text-4xl font-extrabold">R0<span className="text-base font-medium text-ink/50">/forever</span></div>
            <p className="mt-2 text-sm text-ink/60">Everything you need to build and share your family tree.</p>
            <ul className="mt-6 space-y-3">
              {free.map((f) => (
                <li key={f} className="flex items-start gap-3 text-sm">
                  <Icon path={I.check} className="h-5 w-5 text-brand shrink-0" /> {f}
                </li>
              ))}
            </ul>
            <Link to="/app/register" className="btn-ghost w-full mt-8">Get started free</Link>
          </div>
          <div className="card p-8 ring-2 ring-brand relative">
            <span className="absolute -top-3 right-6 rounded-pill bg-sun px-3 py-1 text-xs font-bold text-ink">Most loved</span>
            <h3 className="font-bold text-lg text-brand-700">Premium</h3>
            <div className="mt-2 text-4xl font-extrabold">Upgrade<span className="text-base font-medium text-ink/50"> anytime</span></div>
            <p className="mt-2 text-sm text-ink/60">Unlock on-device face recognition on the mobile app.</p>
            <ul className="mt-6 space-y-3">
              {premium.map((f) => (
                <li key={f} className="flex items-start gap-3 text-sm">
                  <Icon path={I.check} className="h-5 w-5 text-brand shrink-0" /> {f}
                </li>
              ))}
            </ul>
            <Link to="/app/register" className="btn-primary w-full mt-8">Start free, upgrade later</Link>
          </div>
        </div>
      </div>
    </section>
  )
}

function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="py-20 sm:py-28 bg-white border-t border-black/5">
      <div className="container-x max-w-3xl">
        <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-center">Questions, answered</h2>
        <div className="mt-10 divide-y divide-black/5">
          {FAQS.map((f, idx) => (
            <button key={f.q} onClick={() => setOpen(open === idx ? null : idx)} className="w-full text-left py-5">
              <div className="flex items-center justify-between gap-4">
                <span className="font-semibold">{f.q}</span>
                <span className="text-brand text-xl leading-none">{open === idx ? '–' : '+'}</span>
              </div>
              {open === idx && <p className="mt-3 text-sm text-ink/65 leading-relaxed">{f.a}</p>}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}

function CtaBanner() {
  return (
    <section className="py-20">
      <div className="container-x">
        <div className="rounded-2xl bg-brand text-white p-10 sm:p-16 text-center shadow-soft relative overflow-hidden">
          <div className="absolute -top-16 -right-16 h-64 w-64 rounded-full bg-white/10 blur-2xl" />
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Start your family’s living history today</h2>
          <p className="mt-4 text-white/80 max-w-xl mx-auto">It’s free to begin, and your whole family can join in minutes.</p>
          <Link to="/app/register" className="btn bg-white text-brand-700 hover:bg-white/90 mt-8">
            Create your family tree <Icon path={I.arrow} className="h-5 w-5" />
          </Link>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="border-t border-black/5 py-12">
      <div className="container-x flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="flex flex-col items-center sm:items-start gap-2">
          <Logo className="text-brand-700" />
          <p className="text-sm text-ink/50">Your family, beautifully connected.</p>
        </div>
        <div className="flex items-center gap-6 text-sm text-ink/60">
          <a href="#features" className="hover:text-brand-700">Features</a>
          <a href="#pricing" className="hover:text-brand-700">Pricing</a>
          <Link to="/app/sign-in" className="hover:text-brand-700">Log in</Link>
          <Link to="/app/register" className="hover:text-brand-700">Sign up</Link>
        </div>
      </div>
      <div className="container-x mt-8 text-center text-xs text-ink/40">
        © {new Date().getFullYear()} Riza · riza.co.za · All rights reserved.
      </div>
    </footer>
  )
}

export default function LandingPage() {
  return (
    <div className="min-h-screen">
      <Nav />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Pricing />
        <Faq />
        <CtaBanner />
      </main>
      <Footer />
    </div>
  )
}
