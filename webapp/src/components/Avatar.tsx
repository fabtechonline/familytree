import type { Member } from '../lib/types'
import { initials, avatarColor } from '../lib/member-utils'

export default function Avatar({
  member,
  size = 48,
  className = '',
}: {
  member: Pick<Member, 'id' | 'first_name' | 'last_name' | 'photo_url' | 'is_living'>
  size?: number
  className?: string
}) {
  const dim = { width: size, height: size, fontSize: size * 0.4 }
  const ring = member.is_living ? '' : 'grayscale opacity-80'
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
