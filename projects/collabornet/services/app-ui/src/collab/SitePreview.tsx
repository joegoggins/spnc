import type { CollabSite } from './collab'
import { formatDistance } from './collab'
import { AreaMap } from './AreaMap'
import { Markdown } from './Markdown'

// The user-facing site homepage: About, Goals, and Map. Shared by the wizard's
// #preview-homepage step (with the "this is how users see it" banner) and the
// real /collab/:slug page (banner off).
export function SitePreview({
  site,
  banner = false,
}: {
  site: CollabSite
  banner?: boolean
}) {
  return (
    <div className="site-preview">
      {banner && (
        <div className="preview-banner">Your site will look like this to users</div>
      )}

      <header className="site-header">
        <h1>{site.name || 'Untitled Collab Site'}</h1>
      </header>

      {site.aboutMd.trim() && (
        <section className="site-about">
          <Markdown source={site.aboutMd} />
        </section>
      )}

      {site.goals.length > 0 && (
        <section className="site-goals">
          <h2>Our goals</h2>
          <ol className="goal-list">
            {site.goals.map((g, i) => (
              <li key={i}>{g}</li>
            ))}
          </ol>
        </section>
      )}

      <section className="site-map">
        <h2>Our area of stewardship</h2>
        <p className="area-caption">
          {site.primaryArea.label} · {formatDistance(site.primaryArea.radiusM)} radius
        </p>
        <AreaMap
          center={site.primaryArea.center}
          radiusM={site.primaryArea.radiusM}
        />
      </section>
    </div>
  )
}
