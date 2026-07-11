import { Link } from 'react-router-dom'
import { formatDistance, listSites } from './collab'

// GET /collabs — the collabs this user has a stewardship role over. No backend
// yet, so we list what this browser has created; each of those makes you the
// Owner (stand-in until the STEWARDSHIP table from SPNC-0007 exists).
export function CollabsList() {
  const sites = listSites()

  return (
    <section className="collabs-page">
      <header className="collabs-head">
        <h1>Your collabs</h1>
        <Link to="/collab/new" className="cta">
          New collab
        </Link>
      </header>

      {sites.length === 0 ? (
        <div className="collabs-empty">
          <p>You don't steward any collabs yet.</p>
          <Link to="/collab/new" className="cta">
            Create your first collab site
          </Link>
        </div>
      ) : (
        <ul className="collab-cards">
          {sites.map((site) => (
            <li key={site.slug}>
              <Link to={`/collab/${site.slug}`} className="collab-card">
                <div className="collab-card-main">
                  <h2>{site.name}</h2>
                  <p className="collab-card-meta">
                    /collab/{site.slug} · {formatDistance(site.primaryArea.radiusM)} radius ·{' '}
                    {site.goals.length} goals
                  </p>
                </div>
                <span className="role-badge">Owner</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
