import LegalLayout, { H2 } from './LegalLayout'

export default function TermsPage() {
  return (
    <LegalLayout title="Terms of Service" updated="24 June 2026">
      <p>
        These Terms of Service ("Terms") govern your use of Riza, a collaborative
        family-tree app and website (riza.co.za) operated by{' '}
        <strong>Farhad Bux</strong>, trading as <strong>Fabtech Online</strong>
        ("Riza", "we", "us"). By creating an account or using Riza, you agree to
        these Terms. If you do not agree, do not use the service.
      </p>

      <H2>1. The service</H2>
      <p>
        Riza lets you build and share a family tree with relatives — adding
        members, relationships, photos, dates, a map, celebrations and related
        features. We may add, change or remove features over time.
      </p>

      <H2>2. Eligibility and accounts</H2>
      <p>
        You must be at least 18 years old to create an account. You are
        responsible for the activity under your account and for keeping your login
        credentials secure. Notify us promptly of any unauthorised use.
      </p>

      <H2>3. Your content and responsibilities</H2>
      <ul className="list-disc space-y-1 pl-6">
        <li>You retain ownership of the content you add (names, photos, dates, notes and other information).</li>
        <li>You grant us the limited right to store, process and display that content in order to provide the service to you and the members of your family group.</li>
        <li>
          You confirm that you are entitled to add the personal information of
          other people to your family tree, and that doing so does not infringe
          their rights.
        </li>
        <li>You must not upload unlawful, infringing, offensive or harmful content, or misuse the service.</li>
      </ul>

      <H2>4. Family groups and roles</H2>
      <p>
        Content is organised into family groups. Group administrators manage
        membership and roles (such as editor, contributor, relative and viewer),
        which determine who can view or change content. Invite only people you
        intend to share your family information with.
      </p>

      <H2>5. Premium features and payments</H2>
      <p>
        Some features may be offered as premium (for example, AI illustrated
        avatars and on-device face recognition). Where paid plans are introduced,
        the price and terms will be shown to you before you purchase. Unless and
        until billing is enabled, premium features are provided on an as-available
        basis.
      </p>

      <H2>6. Third-party services</H2>
      <p>
        Riza relies on third-party providers (including Supabase, Anthropic,
        OpenStreetMap/Nominatim and Google ML Kit) as described in our{' '}
        <a className="text-brand-700" href="/privacy">Privacy Policy</a>. Your use
        of the service is also subject to those providers' terms where applicable.
      </p>

      <H2>7. Intellectual property</H2>
      <p>
        The Riza app, website, branding and software are owned by Farhad Bux
        (Fabtech Online). These Terms do not grant you any rights in our
        intellectual property beyond using the service as intended.
      </p>

      <H2>8. Disclaimers</H2>
      <p>
        The service is provided "as is" and "as available", without warranties of
        any kind, whether express or implied. We do not warrant that the service
        will be uninterrupted, error-free or that data will never be lost. You are
        responsible for keeping your own copies of important information.
      </p>

      <H2>9. Limitation of liability</H2>
      <p>
        To the maximum extent permitted by law, Riza and Farhad Bux (Fabtech
        Online) will not be liable for any indirect, incidental or consequential
        damages, or for loss of data or profits, arising from your use of (or
        inability to use) the service.
      </p>

      <H2>10. Termination</H2>
      <p>
        You may stop using Riza and request deletion of your account at any time.
        We may suspend or terminate access if these Terms are breached or to
        protect the service or other users.
      </p>

      <H2>11. Changes to these Terms</H2>
      <p>
        We may update these Terms from time to time. We will revise the "Last
        updated" date above and, where appropriate, notify you in the app.
        Continued use after changes means you accept the updated Terms.
      </p>

      <H2>12. Governing law</H2>
      <p>
        These Terms are governed by the laws of the Republic of South Africa, and
        the South African courts will have jurisdiction over any disputes.
      </p>

      <H2>13. Contact us</H2>
      <p>
        Farhad Bux (Fabtech Online) —{' '}
        <a className="text-brand-700" href="mailto:fabtechonline@gmail.com">fabtechonline@gmail.com</a>.
      </p>
    </LegalLayout>
  )
}
