import { Link, Route, Routes } from 'react-router-dom'

function Home() {
  return (
    <section>
      <h1>hello world</h1>
      <p>Collabornet app-ui — React + Vite, served from k3s (gaia) via Cloudflare Tunnel.</p>
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
      </Routes>
    </>
  )
}
