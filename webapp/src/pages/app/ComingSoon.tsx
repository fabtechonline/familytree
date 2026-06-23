import { PageHeader, EmptyState } from '../../components/ui'
import type { IconName } from '../../components/Icon'

export default function ComingSoon({ title, icon }: { title: string; icon: IconName }) {
  return (
    <div>
      <PageHeader title={title} />
      <EmptyState
        icon={icon}
        title="Coming in the next build phase"
        body="This screen is being rebuilt for the web. It’s next on the list."
      />
    </div>
  )
}
