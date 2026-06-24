import LegalLayout, { H2 } from './LegalLayout'

export default function PrivacyPolicyPage() {
  return (
    <LegalLayout title="Privacy Policy" updated="24 June 2026">
      <p>
        Riza ("Riza", "we", "us") is a collaborative family-tree app and website
        (riza.co.za) operated by <strong>Farhad Bux</strong>, trading as{' '}
        <strong>Fabtech Online</strong>, based in South Africa. This policy
        explains what personal information we collect, how we use and protect it,
        and your rights. We process personal information in line with South
        Africa's Protection of Personal Information Act, 2013 (POPIA). Farhad Bux
        is the responsible party / Information Officer.
      </p>
      <p>
        By creating an account or using Riza, you agree to this policy. If you do
        not agree, please do not use the service.
      </p>

      <H2>1. Information we collect</H2>
      <p>We collect the following, most of which you provide directly:</p>
      <ul className="list-disc space-y-1 pl-6">
        <li><strong>Account information:</strong> your email address and authentication details used to sign in.</li>
        <li>
          <strong>Family-tree content you add:</strong> names, relationships,
          dates of birth and death, gender, places of birth, biographies, photos,
          phone numbers, postal/physical addresses, occupations, and memories or
          notes about family members. This may include personal information about
          other people whom you add to your family tree.
        </li>
        <li><strong>Photos:</strong> profile and member photos and "memory" photos you upload.</li>
        <li>
          <strong>Approximate location data:</strong> when you enter a home
          address or birthplace, we convert that text into approximate map
          coordinates (geocoding) to display members on the Family Map.
        </li>
        <li><strong>Limited technical data:</strong> information needed to deliver on-device reminders and to keep the service secure and working.</li>
      </ul>

      <H2>2. How we use your information</H2>
      <ul className="list-disc space-y-1 pl-6">
        <li>To provide the core features: your family tree, members, relationships, feed, celebrations, Family Map, "How related" and other tools.</li>
        <li>To authenticate you and keep your account and family group secure.</li>
        <li>To show birthday and anniversary reminders (these are generated and shown on your own device).</li>
        <li>To provide optional features you choose to use, described below.</li>
      </ul>

      <H2>3. On-device face recognition (optional)</H2>
      <p>
        The optional "Point &amp; Recognize" feature uses on-device machine
        learning (Google ML Kit and TensorFlow Lite). Face detection and matching
        run locally on your device; your face images and the data derived from
        them for this feature are not uploaded to our servers for that purpose.
      </p>

      <H2>4. AI illustrated avatars (optional, premium)</H2>
      <p>
        If you use "Generate avatar from photo", the selected member's photo is
        sent to our AI provider, <strong>Anthropic</strong> (the Claude API),
        which suggests illustrated-avatar features (such as approximate skin tone
        and hair style). The image is processed only to return that result and is
        not used by us, or by Anthropic, to train AI models. If you do not use
        this feature, no photo is sent to Anthropic.
      </p>

      <H2>5. Service providers</H2>
      <p>We use trusted providers to operate Riza. They process data on our behalf:</p>
      <ul className="list-disc space-y-1 pl-6">
        <li><strong>Supabase</strong> — secure database, authentication, file storage and serverless functions where your account and family data are stored.</li>
        <li><strong>Anthropic</strong> — only for the optional AI avatar feature described above.</li>
        <li><strong>OpenStreetMap / Nominatim</strong> — to convert addresses you enter into map coordinates.</li>
        <li><strong>Google ML Kit</strong> — on-device only; used for face detection without sending those images to Google for this purpose.</li>
      </ul>

      <H2>6. How your information is shared</H2>
      <p>
        We do <strong>not</strong> sell your personal information. Content you add
        to a family group is visible to other members of that group according to
        their assigned roles (for example, admins, editors, contributors and
        viewers). We share data with the service providers above only to run the
        app, and we may disclose information if required by law.
      </p>

      <H2>7. Security</H2>
      <p>
        Data is transmitted over encrypted connections (HTTPS) and access is
        restricted by row-level security so that family data is only accessible to
        members of that family group. No method of transmission or storage is
        completely secure, but we take reasonable measures to protect your
        information.
      </p>

      <H2>8. Retention and deletion</H2>
      <p>
        We keep your information for as long as your account and family group
        exist. You can delete members, photos and relationships within the app,
        and you can ask us to delete your account and associated data by emailing{' '}
        <a className="text-brand-700" href="mailto:fabtechonline@gmail.com">fabtechonline@gmail.com</a>.
      </p>

      <H2>9. Children</H2>
      <p>
        Family trees may include information about minors. Only add a child's
        personal information if you are their parent or guardian, or otherwise
        entitled to do so. Riza is not intended for use by children to create
        their own accounts.
      </p>

      <H2>10. Your rights (POPIA)</H2>
      <p>
        You have the right to access, correct, update or delete your personal
        information, to object to certain processing, and to lodge a complaint with
        South Africa's Information Regulator. To exercise these rights, contact our
        Information Officer, Farhad Bux, at{' '}
        <a className="text-brand-700" href="mailto:fabtechonline@gmail.com">fabtechonline@gmail.com</a>.
      </p>

      <H2>11. International processing</H2>
      <p>
        Some of our service providers may store or process data on servers located
        outside South Africa. Where this happens, we rely on those providers'
        safeguards to protect your information.
      </p>

      <H2>12. Changes to this policy</H2>
      <p>
        We may update this policy from time to time. We will revise the "Last
        updated" date above and, where appropriate, notify you in the app.
      </p>

      <H2>13. Contact us</H2>
      <p>
        Farhad Bux (Fabtech Online) —{' '}
        <a className="text-brand-700" href="mailto:fabtechonline@gmail.com">fabtechonline@gmail.com</a>.
      </p>
    </LegalLayout>
  )
}
