import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_providers.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/family/presentation/create_family_screen.dart';
import '../features/family/presentation/home_gate.dart';
import '../features/invite/presentation/invite_screen.dart';
import '../features/invite/presentation/join_family_screen.dart';
import '../features/invite/presentation/members_roles_screen.dart';
import '../features/members/presentation/member_edit_screen.dart';
import '../features/suggestions/presentation/suggestions_screen.dart';
import '../features/tree/presentation/family_tree_screen.dart';

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
      final inAuthFlow = loc == '/sign-in' || loc == '/verify';

      if (!loggedIn) return inAuthFlow ? null : '/sign-in';
      if (loggedIn && inAuthFlow) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeGate()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) =>
            VerifyOtpScreen(email: state.extra as String? ?? ''),
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
        path: '/tree',
        builder: (context, state) => const FamilyTreeScreen(),
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
