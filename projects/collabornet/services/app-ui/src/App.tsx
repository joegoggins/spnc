import type { CSSProperties } from 'react'
import { Link, Route, Routes } from 'react-router-dom'
import mapBg from './assets/radius-map-bg.jpg'
import { NavMenu } from './NavMenu'
import { NewCollabWizard } from './collab/NewCollabWizard'
import { CollabHome } from './collab/CollabHome'
import { CollabsList } from './collab/CollabsList'

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
          Build with people and resources physically closest to you.
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

        <p className="hero-sub">
          Add points to the digital map (like fruit trees),
          create sub-regions (like community gardens),
          and invite neighbors to apply tools, skills, and knowledge to steward
          resources collaboratively.
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

function Settings() {
  return (
    <section className="settings-page">
      <h1>Settings</h1>
      <p className="settings-note">
        Account and site settings will live here. Placeholder for now.
      </p>
      <div className="settings-group">
        <label className="field">
          <span className="field-label">Display name</span>
          <input className="text-input" placeholder="Coming soon" disabled />
        </label>
        <label className="field">
          <span className="field-label">Email</span>
          <input className="text-input" placeholder="Coming soon" disabled />
        </label>
      </div>
    </section>
  )
}

export default function App() {
  return (
    <>
      <header className="topbar">
        <Link to="/" className="brand" aria-label="Home">
          <span className="brand-mark" aria-hidden="true">
            🌱
          </span>
          <span className="brand-name">Collabornet</span>
        </Link>
        <NavMenu />
      </header>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/radius" element={<Radius />} />
        <Route path="/collabs" element={<CollabsList />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/collab/new" element={<NewCollabWizard />} />
        <Route path="/collab/:slug" element={<CollabHome />} />
      </Routes>
    </>
  )
}
