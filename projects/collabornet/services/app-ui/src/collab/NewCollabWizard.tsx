import { useMemo, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import {
  draftToSite,
  emptyDraft,
  formatDistance,
  saveSite,
  slugify,
  type CollabDraft,
  type LatLng,
} from './collab'
import { AreaMap } from './AreaMap'
import { Markdown } from './Markdown'
import { SitePreview } from './SitePreview'

// The 6 onboarding screens from SPNC-0002. Each maps to a URL hash on
// /collab/new so browser back/forward and shareable step links work; the
// draft lives in component state (the route element stays mounted across
// hash changes) and only touches localStorage on "create".
const STEPS = [
  { hash: '', label: 'Basics' },
  { hash: 'inspect-map', label: 'Area' },
  { hash: 'set-goals', label: 'Goals' },
  { hash: 'write-about', label: 'About' },
  { hash: 'preview-homepage', label: 'Preview' },
  { hash: 'final-review', label: 'Create' },
] as const

const RADIUS_MIN = 400
const RADIUS_MAX = 8000

export function NewCollabWizard() {
  const location = useLocation()
  const navigate = useNavigate()
  const [draft, setDraft] = useState<CollabDraft>(emptyDraft)
  const [fitKey, setFitKey] = useState(0)

  const currentHash = location.hash.replace(/^#/, '')
  const foundIndex = STEPS.findIndex((s) => s.hash === currentHash)
  const index = foundIndex < 0 ? 0 : foundIndex

  const goTo = (i: number) => {
    const clamped = Math.max(0, Math.min(STEPS.length - 1, i))
    const h = STEPS[clamped].hash
    navigate(`/collab/new${h ? `#${h}` : ''}`)
  }

  // ── draft mutators ─────────────────────────────────────────────────────────
  const setName = (name: string) =>
    setDraft((d) => ({ ...d, name, slug: d.slugEdited ? d.slug : slugify(name) }))
  const setSlug = (slug: string) =>
    setDraft((d) => ({ ...d, slug: slugify(slug), slugEdited: true }))
  const setGoal = (i: number, value: string) =>
    setDraft((d) => {
      const goals = [...d.goals] as CollabDraft['goals']
      goals[i] = value
      return { ...d, goals }
    })
  const setAbout = (aboutMd: string) => setDraft((d) => ({ ...d, aboutMd }))
  const setCenter = (center: LatLng) =>
    setDraft((d) => ({ ...d, primaryArea: { ...d.primaryArea, center } }))
  const setRadius = (radiusM: number) =>
    setDraft((d) => ({ ...d, primaryArea: { ...d.primaryArea, radiusM } }))

  const locateMe = () => {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition((pos) => {
      setCenter({ lat: pos.coords.latitude, lng: pos.coords.longitude })
      setFitKey((k) => k + 1)
    })
  }

  const create = () => {
    const site = draftToSite(draft, new Date().toISOString())
    saveSite(site)
    navigate(`/collab/${site.slug}`)
  }

  const previewSite = useMemo(() => draftToSite(draft, ''), [draft])
  const canAdvance = index !== 0 || draft.name.trim().length > 0
  const isLast = index === STEPS.length - 1

  return (
    <section className="wizard">
      <ol className="stepper">
        {STEPS.map((s, i) => (
          <li key={s.hash || 'basics'}>
            <button
              className={`step-dot ${i === index ? 'is-current' : ''} ${i < index ? 'is-done' : ''}`}
              onClick={() => goTo(i)}
              aria-current={i === index ? 'step' : undefined}
            >
              <span className="step-dot-n">{i + 1}</span>
              <span className="step-dot-label">{s.label}</span>
            </button>
          </li>
        ))}
      </ol>

      <div className="wizard-body">
        {index === 0 && (
          <div className="step-panel">
            <h1>Create a collab site</h1>
            <p className="step-prompt">
              Start with a name for the place or community you'll be stewarding.
            </p>
            <label className="field">
              <span className="field-label">Site name</span>
              <input
                className="text-input"
                value={draft.name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Powderhorn Park Neighbors"
                autoFocus
              />
            </label>
            <label className="field">
              <span className="field-label">URL slug</span>
              <div className="slug-row">
                <span className="slug-prefix">/collab/</span>
                <input
                  className="text-input"
                  value={draft.slug}
                  onChange={(e) => setSlug(e.target.value)}
                  placeholder="powderhorn-park-neighbors"
                />
              </div>
              <span className="field-hint">Auto-filled from the name; edit if you like.</span>
            </label>
          </div>
        )}

        {index === 1 && (
          <div className="step-panel">
            <h1>Your area of stewardship</h1>
            <p className="step-prompt">
              Drag the pin to the center of the area you'll focus on, and set how
              far your stewardship reaches.
            </p>
            <AreaMap
              center={draft.primaryArea.center}
              radiusM={draft.primaryArea.radiusM}
              onCenterChange={setCenter}
              fitKey={fitKey}
            />
            <div className="map-controls">
              <label className="field radius-field">
                <span className="field-label">
                  Radius · <strong>{formatDistance(draft.primaryArea.radiusM)}</strong>
                </span>
                <input
                  type="range"
                  min={RADIUS_MIN}
                  max={RADIUS_MAX}
                  step={100}
                  value={draft.primaryArea.radiusM}
                  onChange={(e) => setRadius(Number(e.target.value))}
                />
              </label>
              <button className="btn-secondary" onClick={locateMe}>
                📍 Locate me
              </button>
            </div>
            <p className="area-question">
              Is this the correct area that you'll be focused on stewarding? If so,
              hit Next.
            </p>
          </div>
        )}

        {index === 2 && (
          <div className="step-panel">
            <h1>Set your goals</h1>
            <p className="step-prompt">
              Name 3 goals for the people living in this area that you'll be
              collaborating with. Anyone invited to the collab will see these
              prominently when using the site.
            </p>
            <div className="goals-form">
              {draft.goals.map((g, i) => (
                <label className="field" key={i}>
                  <span className="field-label">Goal {i + 1}</span>
                  <input
                    className="text-input"
                    value={g}
                    onChange={(e) => setGoal(i, e.target.value)}
                    placeholder={
                      ['Know every neighbor by name', 'Share tools instead of buying them', 'Green every boulevard'][i]
                    }
                  />
                </label>
              ))}
            </div>
          </div>
        )}

        {index === 3 && (
          <div className="step-panel">
            <h1>Write a welcome message</h1>
            <p className="step-prompt">
              Write a short welcome message people will see before goals. This can
              be a welcome page, have some important contact info, or whatever you
              want your users to see when they login.
            </p>
            <textarea
              className="about-input"
              value={draft.aboutMd}
              onChange={(e) => setAbout(e.target.value)}
              rows={10}
              placeholder={'# Welcome, neighbor\n\nWe look after the blocks around **Powderhorn Park**. Reach me at [hello@example.com](mailto:hello@example.com).'}
            />
            <span className="field-hint">
              Markdown supported — headings, **bold**, *italic*, links, and - lists.
            </span>
            {draft.aboutMd.trim() && (
              <div className="about-preview">
                <span className="field-label">Preview</span>
                <Markdown source={draft.aboutMd} />
              </div>
            )}
          </div>
        )}

        {index === 4 && (
          <div className="step-panel step-panel-preview">
            <SitePreview site={previewSite} banner />
          </div>
        )}

        {index === 5 && (
          <div className="step-panel">
            <h1>One last look</h1>
            <p className="step-prompt">Everything look good? Create the collab site?</p>
            <dl className="review-summary">
              <div>
                <dt>Name</dt>
                <dd>{draft.name || <em>—</em>}</dd>
              </div>
              <div>
                <dt>URL</dt>
                <dd>/collab/{draft.slug || slugify(draft.name)}</dd>
              </div>
              <div>
                <dt>Area</dt>
                <dd>
                  {draft.primaryArea.label} · {formatDistance(draft.primaryArea.radiusM)} radius
                </dd>
              </div>
              <div>
                <dt>Goals</dt>
                <dd>{draft.goals.filter(Boolean).length} of 3 set</dd>
              </div>
              <div>
                <dt>Welcome</dt>
                <dd>{draft.aboutMd.trim() ? 'Written' : 'Empty'}</dd>
              </div>
            </dl>
          </div>
        )}
      </div>

      <div className="wizard-nav">
        <button className="btn-secondary" onClick={() => goTo(index - 1)} disabled={index === 0}>
          ‹ Back
        </button>
        {isLast ? (
          <button className="cta" onClick={create}>
            Yes, let's do it
          </button>
        ) : (
          <button className="cta" onClick={() => goTo(index + 1)} disabled={!canAdvance}>
            Next ›
          </button>
        )}
      </div>
    </section>
  )
}
