export const ICONS = {
  dashboard: 'M4 13h6V4H4v9Zm0 7h6v-5H4v5Zm10 0h6v-9h-6v9Zm0-16v5h6V4h-6Z',
  tree: 'M12 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Zm0 6v4m0 0H7a2 2 0 0 0-2 2v2m9-4h5a2 2 0 0 1 2 2v2M3 19a2 2 0 1 0 4 0 2 2 0 0 0-4 0Zm14 0a2 2 0 1 0 4 0 2 2 0 0 0-4 0Z',
  members: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm14 10v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11',
  feed: 'M4 6h16M4 12h16M4 18h10',
  gift: 'M20 12v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8M2 7h20v5H2zM12 7v14M12 7S9 2 6.5 4.5 12 7 12 7Zm0 0s3-5 5.5-2.5S12 7 12 7Z',
  link: 'M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1m-1 8a5 5 0 0 1-7 0 5 5 0 0 1 0-7l2-2a5 5 0 0 1 7 0l1 1',
  chart: 'M4 19V5m0 14h16M8 17v-5m4 5V9m4 8v-7',
  clock: 'M12 7v5l3 2m6-2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  capsule: 'M9 3h6m-3 0v4m-5 0h10l-1 12a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2L7 7Z',
  invite: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm10-4v6m3-3h-6',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3Z',
  inbox: 'M22 12h-6l-2 3h-4l-2-3H2m20 0-3.5-7A2 2 0 0 0 16.7 4H7.3a2 2 0 0 0-1.8 1L2 12m20 0v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-6',
  crown: 'M3 6l4 4 5-6 5 6 4-4-2 13H5L3 6Z',
  plus: 'M12 5v14M5 12h14',
  check: 'M20 6 9 17l-5-5',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  logout: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5m5 5H9',
  chevron: 'm6 9 6 6 6-6',
  user: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  edit: 'M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7m-2.5-9.5a2.12 2.12 0 0 1 3 3L12 16l-4 1 1-4 9.5-9.5Z',
  camera: 'M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2v11ZM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  trash: 'M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6h14ZM10 11v6M14 11v6',
  map: 'M9 3 3 6v15l6-3 6 3 6-3V3l-6 3-6-3Zm0 0v15m6-12v15',
  globe: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0 0c2.5-2.3 4-5.6 4-9s-1.5-6.7-4-9m0 18c-2.5-2.3-4-5.6-4-9s1.5-6.7 4-9M3.5 9h17M3.5 15h17',
} as const

export type IconName = keyof typeof ICONS

export default function Icon({ name, className }: { name: IconName; className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden="true">
      <path d={ICONS[name]} stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
