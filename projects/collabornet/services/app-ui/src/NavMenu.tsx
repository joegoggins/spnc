import { useEffect, useRef, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'

// Top-right hamburger menu. No auth yet, so "Log out" is a placeholder that
// just returns to the splash page (real logout arrives with SSO — SPNC-0001).
export function NavMenu() {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const location = useLocation()
  const navigate = useNavigate()

  // Close on route change.
  useEffect(() => setOpen(false), [location.pathname])

  // Close on outside click / Escape.
  useEffect(() => {
    if (!open) return
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onClick)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onClick)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  const logOut = () => {
    setOpen(false)
    navigate('/')
  }

  return (
    <div className="nav-menu" ref={ref}>
      <button
        className="hamburger"
        aria-label="Menu"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
      >
        <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
          {open ? (
            <g stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="5" y1="5" x2="17" y2="17" />
              <line x1="17" y1="5" x2="5" y2="17" />
            </g>
          ) : (
            <g stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="3" y1="6" x2="19" y2="6" />
              <line x1="3" y1="11" x2="19" y2="11" />
              <line x1="3" y1="16" x2="19" y2="16" />
            </g>
          )}
        </svg>
      </button>

      {open && (
        <div className="menu-panel" role="menu">
          <Link to="/collabs" className="menu-item" role="menuitem">
            Collabs
          </Link>
          <Link to="/settings" className="menu-item" role="menuitem">
            Settings
          </Link>
          <div className="menu-divider" />
          <button className="menu-item" role="menuitem" onClick={logOut}>
            Log out
          </button>
        </div>
      )}
    </div>
  )
}
