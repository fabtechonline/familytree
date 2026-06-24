import { Navigate, Route, Routes } from 'react-router-dom'
import LandingPage from './pages/marketing/LandingPage'
import SignInPage from './pages/auth/SignInPage'
import RegisterPage from './pages/auth/RegisterPage'
import VerifyOtpPage from './pages/auth/VerifyOtpPage'
import ProtectedRoute from './auth/ProtectedRoute'
import { FamilyProvider } from './app/FamilyProvider'
import AppShell from './app/AppShell'
import DashboardPage from './pages/app/DashboardPage'
import CreateFamilyPage from './pages/app/CreateFamilyPage'
import TreePage from './pages/app/TreePage'
import MapPage from './pages/app/MapPage'
import MembersPage from './pages/app/MembersPage'
import MemberProfilePage from './pages/app/MemberProfilePage'
import MemberEditPage from './pages/app/MemberEditPage'
import FeedPage from './pages/app/FeedPage'
import CelebrationsPage from './pages/app/CelebrationsPage'
import RelatePage from './pages/app/RelatePage'
import InsightsPage from './pages/app/InsightsPage'
import TimeMachinePage from './pages/app/TimeMachinePage'
import CapsulesPage from './pages/app/CapsulesPage'
import AccountPage from './pages/app/AccountPage'
import AboutPage from './pages/app/AboutPage'
import PrivacyPolicyPage from './pages/legal/PrivacyPolicyPage'
import TermsPage from './pages/legal/TermsPage'
import InvitePage from './pages/app/InvitePage'
import JoinFamilyPage from './pages/app/JoinFamilyPage'
import SuggestionsPage from './pages/app/SuggestionsPage'
import SuperAdminPage from './pages/app/SuperAdminPage'

/** Everything under /app requires auth + family context. */
function ProtectedApp({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute>
      <FamilyProvider>{children}</FamilyProvider>
    </ProtectedRoute>
  )
}

export default function App() {
  return (
    <Routes>
      {/* Marketing */}
      <Route path="/" element={<LandingPage />} />

      {/* Legal (public) */}
      <Route path="/privacy" element={<PrivacyPolicyPage />} />
      <Route path="/terms" element={<TermsPage />} />

      {/* Auth (public) */}
      <Route path="/app/sign-in" element={<SignInPage />} />
      <Route path="/app/register" element={<RegisterPage />} />
      <Route path="/app/verify" element={<VerifyOtpPage />} />

      {/* Onboarding + super-admin (protected, no shell, no family gate) */}
      <Route path="/app/create-family" element={<ProtectedApp><CreateFamilyPage /></ProtectedApp>} />
      <Route path="/app/admin" element={<ProtectedApp><SuperAdminPage /></ProtectedApp>} />

      {/* App (protected, with shell) */}
      <Route path="/app" element={<ProtectedApp><AppShell /></ProtectedApp>}>
        <Route index element={<DashboardPage />} />
        <Route path="tree" element={<TreePage />} />
        <Route path="map" element={<MapPage />} />
        <Route path="members" element={<MembersPage />} />
        <Route path="members/new" element={<MemberEditPage />} />
        <Route path="member/:id" element={<MemberProfilePage />} />
        <Route path="member/:id/edit" element={<MemberEditPage />} />
        <Route path="feed" element={<FeedPage />} />
        <Route path="celebrations" element={<CelebrationsPage />} />
        <Route path="relate" element={<RelatePage />} />
        <Route path="insights" element={<InsightsPage />} />
        <Route path="timemachine" element={<TimeMachinePage />} />
        <Route path="capsules" element={<CapsulesPage />} />
        <Route path="invite" element={<InvitePage />} />
        <Route path="join" element={<JoinFamilyPage />} />
        <Route path="suggestions" element={<SuggestionsPage />} />
        <Route path="account" element={<AccountPage />} />
        <Route path="about" element={<AboutPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
