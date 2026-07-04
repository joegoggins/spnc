import { useEffect } from 'react'
import L from 'leaflet'
import { Circle, MapContainer, Marker, TileLayer, useMap } from 'react-leaflet'
import type { LatLng } from './collab'

// A leaf-green pin drawn as a divIcon so we don't depend on Leaflet's default
// marker PNGs (which break under bundlers without extra asset wiring).
const pinIcon = L.divIcon({
  className: 'area-pin',
  html: '<span class="area-pin-dot"></span>',
  iconSize: [20, 20],
  iconAnchor: [10, 10],
})

const CIRCLE_STYLE = {
  color: '#3f8f5b',
  weight: 2,
  fillColor: '#3f8f5b',
  fillOpacity: 0.12,
}

/**
 * Keep the circle framed: fit bounds on mount, whenever the radius changes, and
 * whenever `fitKey` bumps (e.g. after "Locate me"). Deliberately NOT on every
 * pin drag, so dragging the center doesn't make the map jump.
 */
function FitToCircle({
  center,
  radiusM,
  fitKey,
}: {
  center: LatLng
  radiusM: number
  fitKey: number
}) {
  const map = useMap()
  useEffect(() => {
    // Compute bounds from the point + diameter directly. (Do NOT use a detached
    // L.circle().getBounds() — that reaches through this._map and throws before
    // the circle is attached to a map.)
    const bounds = L.latLng(center.lat, center.lng).toBounds(radiusM * 2)
    map.fitBounds(bounds, { padding: [24, 24] })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [radiusM, fitKey])
  return null
}

/** Leaflet needs a real size; nudge it after mount in case the square sized late. */
function InvalidateOnMount() {
  const map = useMap()
  useEffect(() => {
    const id = setTimeout(() => map.invalidateSize(), 0)
    return () => clearTimeout(id)
  }, [map])
  return null
}

type Props = {
  center: LatLng
  radiusM: number
  /** editable => draggable pin + refit on radius; omit for a read-only snapshot */
  onCenterChange?: (c: LatLng) => void
  /** bump to force a refit (e.g. after "Locate me" recenters the pin) */
  fitKey?: number
}

export function AreaMap({ center, radiusM, onCenterChange, fitKey = 0 }: Props) {
  const editable = typeof onCenterChange === 'function'
  return (
    <div className="map-square">
      <MapContainer
        center={[center.lat, center.lng]}
        zoom={13}
        scrollWheelZoom={editable}
        dragging={editable}
        doubleClickZoom={editable}
        zoomControl={editable}
        attributionControl
        style={{ height: '100%', width: '100%' }}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
        <Circle center={[center.lat, center.lng]} radius={radiusM} pathOptions={CIRCLE_STYLE} />
        <Marker
          position={[center.lat, center.lng]}
          icon={pinIcon}
          draggable={editable}
          eventHandlers={
            editable
              ? {
                  dragend: (e) => {
                    const { lat, lng } = e.target.getLatLng()
                    onCenterChange!({ lat, lng })
                  },
                }
              : undefined
          }
        />
        <InvalidateOnMount />
        {editable && <FitToCircle center={center} radiusM={radiusM} fitKey={fitKey} />}
      </MapContainer>
    </div>
  )
}
