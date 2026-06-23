export interface GeoResult {
  lat: number
  lng: number
  label?: string
}

/**
 * Geocode a free-text place (address or birthplace) to coordinates via the free
 * OpenStreetMap Nominatim service. Best-effort: returns null on any failure so
 * callers never block a save. The `email` param satisfies Nominatim's usage policy.
 */
export async function geocode(query: string): Promise<GeoResult | null> {
  const q = query.trim()
  if (!q) return null
  const url =
    'https://nominatim.openstreetmap.org/search?format=json&limit=1' +
    `&email=info@riza.co.za&q=${encodeURIComponent(q)}`
  try {
    const res = await fetch(url, { headers: { Accept: 'application/json' } })
    if (!res.ok) return null
    const data = (await res.json()) as Array<{ lat: string; lon: string; display_name?: string }>
    if (!Array.isArray(data) || data.length === 0) return null
    const r = data[0]
    const lat = parseFloat(r.lat)
    const lng = parseFloat(r.lon)
    if (Number.isNaN(lat) || Number.isNaN(lng)) return null
    return { lat, lng, label: r.display_name }
  } catch {
    return null
  }
}
