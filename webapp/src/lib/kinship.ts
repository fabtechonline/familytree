type Via = 'parent' | 'child' | 'partner'

const ordinal = (n: number) => {
  const s = ['th', 'st', 'nd', 'rd']
  const v = n % 100
  return n + (s[(v - 20) % 10] || s[v] || s[0])
}
const greats = (n: number) => (n <= 0 ? '' : n === 1 ? 'great-' : `${ordinal(n)}-great-`)

/** Plain-English kinship term from a relation path (A→B), B relative to A. */
export function describeKinship(path: { via: Via }[]): string {
  if (path.length === 0) return 'the same person'
  const ups = path.filter((p) => p.via === 'parent').length
  const downs = path.filter((p) => p.via === 'child').length
  const partners = path.filter((p) => p.via === 'partner').length

  // Pure partner
  if (ups === 0 && downs === 0 && partners > 0) return 'partner / spouse'

  const inLaw = partners > 0 ? '-in-law' : ''

  // Direct ancestors / descendants
  if (ups > 0 && downs === 0) {
    if (ups === 1) return `parent${inLaw}`
    if (ups === 2) return `grandparent${inLaw}`
    return `${greats(ups - 2)}grandparent${inLaw}`
  }
  if (downs > 0 && ups === 0) {
    if (downs === 1) return `child${inLaw}`
    if (downs === 2) return `grandchild${inLaw}`
    return `${greats(downs - 2)}grandchild${inLaw}`
  }

  // Collateral
  if (ups === 1 && downs === 1) return `sibling${inLaw}`
  if (ups === 1 && downs >= 2) return `${greats(downs - 2)}grand niece/nephew${inLaw}`.replace('grand niece', downs === 2 ? 'niece' : 'grand-niece')
  if (downs === 1 && ups >= 2) return `${greats(ups - 2)}grand aunt/uncle${inLaw}`.replace('grand aunt', ups === 2 ? 'aunt/uncle' : 'grand-aunt')

  // Cousins
  const cousinDegree = Math.min(ups, downs) - 1
  const removed = Math.abs(ups - downs)
  let term = `${ordinal(cousinDegree)} cousin`
  if (removed > 0) term += `, ${removed} time${removed > 1 ? 's' : ''} removed`
  return term + inLaw
}
