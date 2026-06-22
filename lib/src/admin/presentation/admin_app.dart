import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/supabase_providers.dart';
import '../data/admin_repository.dart';
import 'admin_home_screen.dart';
import 'admin_login_screen.dart';

/// The Super-Admin web console app. Distinct (indigo) theme to make it obvious
/// this is the platform console, not the consumer app.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4C5BD4),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'FamilyTree Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        textTheme: GoogleFonts.interTextTheme(),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      home: const _AdminGate(),
    );
  }
}

class _AdminGate extends ConsumerWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const AdminLoginScreen();

    return FutureBuilder<bool>(
      future: ref.watch(adminRepositoryProvider).isSuperAdmin(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == true) return const AdminHomeScreen();
        return _NotAuthorized(
            onSignOut: () => ref.read(adminRepositoryProvider).signOut());
      },
    );
  }
}

class _NotAuthorized extends StatelessWidget {
  const _NotAuthorized({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('This account is not a platform administrator.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
