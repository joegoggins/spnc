import type { CSSProperties } from 'react'
import { Link, Route, Routes } from 'react-router-dom'
import mapBg from './assets/radius-map-bg.jpg'
import { NewCollabWizard } from './collab/NewCollabWizard'
import { CollabHome } from './collab/CollabHome'

const STEPS = [
  { n: 1, text: 'Make a map.' },
  { n: 2, text: 'Print it big.' },
  { n: 3, text: 'Frame it, hang it, make it look cool.' },
]

function Home() {
  return (
    <section
      className="home-hero"
      style={{ '--hero-bg': `url(${mapBg})` } as CSSProperties}
    >
      <div className="hero-content">
        <h1>Radius of Stewardship</h1>

        <p className="hero-lead">
          Rebuilding the world begins by declaring stewardship over the
          immediate area where you live.
        </p>
        <p className="hero-sub">
          Focus on building relationships with the people, businesses, and
          organizations physically closest to you.
        </p>

        <ol className="steps">
          {STEPS.map((s) => (
            <li key={s.n} className="step">
              <span className="step-n">{s.n}</span>
              <span className="step-text">{s.text}</span>
            </li>
          ))}
        </ol>

        <p className="hero-sub">
          Every day, when you see it, it will help you anchor where you are.
          Over time, put pins on it, annotate it, draw on it &mdash; turn it
          into something alive, embedded with stories.
        </p>

        <Link to="/collab/new" className="cta">
          Get Started
        </Link>
      </div>
    </section>
  )
}

function Radius() {
  return (
    <section>
      <h1>Radius of Stewardship</h1>
      <p>The world map + radius picker lands here next.</p>
    </section>
  )
}

export default function App() {
  return (
    <>
      <nav style={{ padding: '1rem' }}>
        <Link to="/">Home</Link> · <Link to="/radius">Radius of Stewardship</Link>
      </nav>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/radius" element={<Radius />} />
        <Route path="/collab/new" element={<NewCollabWizard />} />
        <Route path="/collab/:slug" element={<CollabHome />} />
      </Routes>
    </>
  )
}
