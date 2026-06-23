import type { Member } from '../lib/types'
import { initials, avatarColor } from '../lib/member-utils'
import { avatarUrl } from '../lib/avatar'

export default function Avatar({
  member,
  size = 48,
  className = '',
}: {
  member: Pick<Member, 'id' | 'first_name' | 'last_name' | 'photo_url' | 'is_living' | 'avatar_config'>
  size?: number
  className?: string
}) {
  const dim = { width: size, height: size, fontSize: size * 0.4 }
  const ring = member.is_living ? '' : 'grayscale opacity-80'

  // Priority: illustrated avatar (deliberate choice) → real photo → initials.
  if (member.avatar_config) {
    return (
      <img
        src={avatarUrl(member.avatar_config, Math.round(size * 2))}
        alt=""
        style={dim}
        className={`rounded-full object-cover bg-brand-50 ${ring} ${className}`}
      />
    )
  }
  if (member.photo_url) {
    return (
      <img
        src={member.photo_url}
        alt=""
        style={dim}
        className={`rounded-full object-cover ${ring} ${className}`}
      />
    )
  }
  return (
    <div
      style={{ ...dim, backgroundColor: avatarColor(member.id) }}
      className={`rounded-full grid place-items-center font-bold text-white ${ring} ${className}`}
    >
      {initials(member)}
    </div>
  )
}
