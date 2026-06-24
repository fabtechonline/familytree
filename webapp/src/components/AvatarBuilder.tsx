import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { updateMember } from '../data/mutations'
import { avatarUrl, AVATAR_STYLE, SKIN_TONES, HAIR_COLORS, HAIR_STYLES } from '../lib/avatar'
import type { AvatarConfig, Member } from '../lib/types'
import { generateAvatarFromPhoto } from '../lib/generate-avatar'
import { usePublicSettings } from '../data/settings'
import Icon from './Icon'

const randomSeed = () => Math.random().toString(36).slice(2, 10)

export default function AvatarBuilder({
  member,
  familyId,
  isPremium,
  onClose,
}: {
  member: Member
  familyId: string
  isPremium: boolean
  onClose: () => void
}) {
  const qc = useQueryClient()
  const { data: settings } = usePublicSettings()
  const canAi = isPremium && settings?.features.ai_avatar !== false
  const [config, setConfig] = useState<AvatarConfig>(
    member.avatar_config ?? { style: AVATAR_STYLE, seed: member.id.slice(0, 8), options: {} },
  )
  const [busy, setBusy] = useState(false)
  const [aiBusy, setAiBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const opt = (config.options ?? {}) as Record<string, string | number>
  const setOpt = (k: string, v: string | number) =>
    setConfig((c) => ({ ...c, options: { ...(c.options ?? {}), [k]: v } }))
  const glassesOn = opt.glassesProbability === 100

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['members', familyId] })
    qc.invalidateQueries({ queryKey: ['member', member.id] })
  }

  const save = async () => {
    setBusy(true)
    setError(null)
    try {
      await updateMember(member.id, { avatar_config: config, family_id: familyId, first_name: member.first_name })
      refresh()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not save')
    } finally {
      setBusy(false)
    }
  }

  const remove = async () => {
    setBusy(true)
    try {
      await updateMember(member.id, { avatar_config: null as unknown as undefined, family_id: familyId, first_name: member.first_name })
      refresh()
      onClose()
    } finally {
      setBusy(false)
    }
  }

  const generateFromPhoto = async () => {
    if (!member.photo_url) return
    setAiBusy(true)
    setError(null)
    try {
      const ai = await generateAvatarFromPhoto(member.id)
      setConfig(ai)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'AI generation failed')
    } finally {
      setAiBusy(false)
    }
  }

  const Swatch = ({ color, active, onClick }: { color: string; active: boolean; onClick: () => void }) => (
    <button
      onClick={onClick}
      className={`h-8 w-8 rounded-full border-2 ${active ? 'border-brand ring-2 ring-brand/40' : 'border-black/10'}`}
      style={{ backgroundColor: `#${color}` }}
      aria-label={color}
    />
  )

  return (
    <div className="fixed inset-0 z-50 bg-black/40 grid place-items-center p-4" onClick={onClose}>
      <div className="w-full max-w-lg card p-6 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold">Illustrated avatar</h2>
          <button onClick={onClose} className="text-ink/40 hover:text-ink text-xl leading-none">×</button>
        </div>

        <div className="flex flex-col items-center">
          <img src={avatarUrl(config, 320)} alt="" className="h-40 w-40 rounded-full bg-brand-50 object-cover" />
          <div className="mt-3 flex gap-2">
            <button onClick={() => setConfig((c) => ({ ...c, seed: randomSeed() }))} className="btn-ghost h-10">
              <Icon name="arrow" className="h-4 w-4" /> Shuffle
            </button>
            {member.photo_url && (
              <button
                onClick={canAi ? generateFromPhoto : undefined}
                disabled={aiBusy || !canAi}
                title={canAi ? 'Match this avatar to the photo' : 'Premium feature'}
                className="btn-primary h-10 disabled:opacity-60"
              >
                <Icon name="crown" className="h-4 w-4" /> {aiBusy ? 'Analyzing…' : 'Generate from photo'}
              </button>
            )}
          </div>
          {member.photo_url && !canAi && (
            <p className="mt-1 text-xs text-ink/45">
              {isPremium ? 'AI avatars are temporarily unavailable.' : 'AI “generate from photo” is a Premium feature.'}
            </p>
          )}
        </div>

        <div className="mt-6 space-y-4">
          <div>
            <div className="text-sm font-medium mb-2">Skin tone</div>
            <div className="flex flex-wrap gap-2">
              {SKIN_TONES.map((c) => <Swatch key={c} color={c} active={opt.skinColor === c} onClick={() => setOpt('skinColor', c)} />)}
            </div>
          </div>
          <div>
            <div className="text-sm font-medium mb-2">Hair colour</div>
            <div className="flex flex-wrap gap-2">
              {HAIR_COLORS.map((c) => <Swatch key={c} color={c} active={opt.hairColor === c} onClick={() => setOpt('hairColor', c)} />)}
            </div>
          </div>
          <div>
            <div className="text-sm font-medium mb-2">Hair style</div>
            <div className="flex flex-wrap gap-2">
              {HAIR_STYLES.map((h, i) => (
                <button key={h} onClick={() => setOpt('hair', h)}
                  className={`rounded-pill px-3 py-1.5 text-sm border ${opt.hair === h ? 'bg-brand text-white border-brand' : 'border-black/10 hover:border-brand/40'}`}>
                  {i + 1}
                </button>
              ))}
            </div>
          </div>
          <label className="flex items-center gap-3 text-sm">
            <input type="checkbox" className="h-5 w-5 rounded accent-brand" checked={glassesOn}
              onChange={(e) => setOpt('glassesProbability', e.target.checked ? 100 : 0)} />
            Glasses
          </label>
        </div>

        {error && <p className="text-sm text-coral mt-4">{error}</p>}

        <div className="mt-6 flex items-center justify-between">
          <button onClick={save} disabled={busy} className="btn-primary">{busy ? 'Saving…' : 'Use this avatar'}</button>
          {member.avatar_config && (
            <button onClick={remove} disabled={busy} className="text-sm text-coral hover:underline">Remove avatar</button>
          )}
        </div>
      </div>
    </div>
  )
}
