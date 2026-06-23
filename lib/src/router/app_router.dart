import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_providers.dart';
import '../features/auth/presentation/landing_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/family/presentation/create_family_screen.dart';
import '../features/family/presentation/home_gate.dart';
import '../features/invite/presentation/invite_screen.dart';
import '../features/invite/presentation/join_family_screen.dart';
import '../features/invite/presentation/members_roles_screen.dart';
import '../features/announcements/presentation/announcements_screen.dart';
import '../features/celebrations/presentation/celebrations_screen.dart';
import '../features/capsules/capsules_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/premium/point_recognize_screen.dart';
import '../features/relate/relate_screen.dart';
import '../features/timemachine/time_machine_screen.dart';
import '../features/members/presentation/member_edit_screen.dart';
import '../features/members/presentation/member_profile_screen.dart';
import '../features/suggestions/presentation/suggestions_screen.dart';
import '../features/tree/presentation/family_tree_screen.dart';
import '../features/map/presentation/family_map_screen.dart';

/// App router. Redirects unauthenticated users to sign-in and authenticated
/// users away from auth screens, reacting live to Supabase auth changes.
final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;
      // Screens reachable without a session.
      const unauthRoutes = {'/landing', '/sign-in', '/register', '/verify'};

      if (!loggedIn) return unauthRoutes.contains(loc) ? null : '/landing';
      if (loggedIn && unauthRoutes.contains(loc)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeGate()),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            return VerifyOtpScreen(
              email: extra['email'] as String? ?? '',
              signup: extra['signup'] == true,
            );
          }
          return VerifyOtpScreen(email: extra as String? ?? '');
        },
      ),
      GoRoute(
        path: '/create-family',
        builder: (context, state) => const CreateFamilyScreen(),
      ),
      GoRoute(
        path: '/member/new',
        builder: (context, state) => const MemberEditScreen(),
      ),
      GoRoute(
        path: '/member/:id',
        builder: (context, state) =>
            MemberEditScreen(memberId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) =>
            MemberProfileScreen(memberId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/celebrations',
        builder: (context, state) => const CelebrationsScreen(),
      ),
      GoRoute(
        path: '/relate',
        builder: (context, state) => const RelateScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/timemachine',
        builder: (context, state) => const TimeMachineScreen(),
      ),
      GoRoute(
        path: '/capsules',
        builder: (context, state) => const CapsulesScreen(),
      ),
      GoRoute(
        path: '/recognize',
        builder: (context, state) => const PointRecognizeScreen(),
      ),
      GoRoute(
        path: '/tree',
        builder: (context, state) => const FamilyTreeScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const FamilyMapScreen(),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinFamilyScreen(),
      ),
      GoRoute(
        path: '/members-roles',
        builder: (context, state) => const MembersRolesScreen(),
      ),
      GoRoute(
        path: '/suggestions',
        builder: (context, state) => const SuggestionsScreen(),
      ),
    ],
  );
});

/// Bridges a [Stream] to a [Listenable] so GoRouter re-evaluates redirects when
/// the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
