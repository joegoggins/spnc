// Shared types + client-side persistence for the "create a collab site" flow
// (SPNC-0002). No backend yet — the wizard collects a draft entirely in the
// browser and, on "create", stashes the finished site in localStorage so
// /collab/:slug renders like a real page and survives a refresh.

export type LatLng = { lat: number; lng: number }

/** The primary AREA_OF_STEWARDSHIP (is_primary=true) from SPNC-0007. */
export type PrimaryArea = {
  center: LatLng
  radiusM: number
  label: string
}

/** A COLLAB_SITE plus its primary area, as collected by the wizard. */
export type CollabSite = {
  name: string
  slug: string
  aboutMd: string
  goals: string[] // list of 3
  primaryArea: PrimaryArea
  createdAt: string
}

/** In-progress wizard state (mutable, pre-create). */
export type CollabDraft = {
  name: string
  slug: string
  slugEdited: boolean // once the user hand-edits the slug, stop auto-deriving
  aboutMd: string
  goals: [string, string, string]
  primaryArea: PrimaryArea
}

// Default the starting circle to ~1 mile over Minneapolis (mspsolarpunk).
export const DEFAULT_CENTER: LatLng = { lat: 44.9778, lng: -93.265 }
export const DEFAULT_RADIUS_M = 1609 // 1 mile

export function emptyDraft(): CollabDraft {
  return {
    name: '',
    slug: '',
    slugEdited: false,
    aboutMd: '',
    goals: ['', '', ''],
    primaryArea: {
      center: { ...DEFAULT_CENTER },
      radiusM: DEFAULT_RADIUS_M,
      label: '1 mile ring',
    },
  }
}

/** name -> url-safe slug */
export function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
}

export function draftToSite(draft: CollabDraft, createdAt: string): CollabSite {
  return {
    name: draft.name.trim(),
    slug: draft.slug || slugify(draft.name),
    aboutMd: draft.aboutMd,
    goals: draft.goals.map((g) => g.trim()).filter(Boolean),
    primaryArea: draft.primaryArea,
    createdAt,
  }
}

// ── localStorage persistence ────────────────────────────────────────────────
const STORAGE_KEY = 'collabornet.sites.v1'

type SiteMap = Record<string, CollabSite>

function readAll(): SiteMap {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as SiteMap) : {}
  } catch {
    return {}
  }
}

export function saveSite(site: CollabSite): void {
  const all = readAll()
  all[site.slug] = site
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all))
}

export function loadSite(slug: string): CollabSite | null {
  return readAll()[slug] ?? null
}

// ── formatting helpers ───────────────────────────────────────────────────────
export function formatDistance(meters: number): string {
  const miles = meters / 1609.34
  if (miles < 0.95) return `${Math.round(meters)} m`
  return `${miles.toFixed(miles < 10 ? 1 : 0)} mi`
}
