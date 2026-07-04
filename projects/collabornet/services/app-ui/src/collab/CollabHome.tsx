import { Link, useParams } from 'react-router-dom'
import { loadSite } from './collab'
import { SitePreview } from './SitePreview'

// GET /collab/:slug — renders the created site exactly like #preview-homepage,
// minus the wizard banner. Reads from localStorage (no backend yet).
export function CollabHome() {
  const { slug = '' } = useParams()
  const site = loadSite(slug)

  if (!site) {
    return (
      <section className="collab-empty">
        <h1>Site not found</h1>
        <p>
          No collab site is stored for <code>{slug}</code> in this browser. It may
          have been created elsewhere, or storage was cleared.
        </p>
        <Link to="/collab/new" className="cta">
          Create a collab site
        </Link>
      </section>
    )
  }

  return <SitePreview site={site} />
}
