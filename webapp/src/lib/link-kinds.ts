// Mirrors the mobile app's _LinkKind: how a new member links to an existing
// anchor, implying the new member's gender and which edges to create.

export type RelCategory = 'spouse' | 'parent' | 'child' | 'sibling' | 'none'

export type LinkKind =
  | 'husbandOf' | 'wifeOf'
  | 'fatherOf' | 'motherOf'
  | 'sonOf' | 'daughterOf'
  | 'brotherOf' | 'sisterOf'
  | 'none'

export const linkLabel: Record<LinkKind, string> = {
  husbandOf: 'Husband of',
  wifeOf: 'Wife of',
  fatherOf: 'Father of',
  motherOf: 'Mother of',
  sonOf: 'Son of',
  daughterOf: 'Daughter of',
  brotherOf: 'Brother of',
  sisterOf: 'Sister of',
  none: 'No link',
}

export function impliedGender(k: LinkKind): string | null {
  switch (k) {
    case 'wifeOf': case 'motherOf': case 'daughterOf': case 'sisterOf':
      return 'female'
    case 'husbandOf': case 'fatherOf': case 'sonOf': case 'brotherOf':
      return 'male'
    default:
      return null
  }
}

export function categoryOf(k: LinkKind): RelCategory {
  switch (k) {
    case 'husbandOf': case 'wifeOf': return 'spouse'
    case 'fatherOf': case 'motherOf': return 'parent'
    case 'sonOf': case 'daughterOf': return 'child'
    case 'brotherOf': case 'sisterOf': return 'sibling'
    default: return 'none'
  }
}

export function forCategoryGender(cat: RelCategory, male: boolean): LinkKind {
  switch (cat) {
    case 'spouse': return male ? 'husbandOf' : 'wifeOf'
    case 'parent': return male ? 'fatherOf' : 'motherOf'
    case 'child': return male ? 'sonOf' : 'daughterOf'
    case 'sibling': return male ? 'brotherOf' : 'sisterOf'
    case 'none': return 'none'
  }
}

export function forGender(gender: string | null | undefined): LinkKind[] {
  if (gender === 'male') return ['husbandOf', 'fatherOf', 'sonOf', 'brotherOf', 'none']
  if (gender === 'female') return ['wifeOf', 'motherOf', 'daughterOf', 'sisterOf', 'none']
  return ['husbandOf', 'wifeOf', 'fatherOf', 'motherOf', 'sonOf', 'daughterOf', 'brotherOf', 'sisterOf', 'none']
}
