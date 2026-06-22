import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_providers.dart';

/// The current user's account status ('active' | 'blocked' | 'suspended').
/// Used to lock blocked/suspended users out of the app.
final accountStatusProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  // Re-check whenever auth changes (sign-in/out).
  ref.watch(authStateChangesProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return 'active';
  final row = await client
      .from('profiles')
      .select('status')
      .eq('id', uid)
      .maybeSingle();
  return (row?['status'] as String?) ?? 'active';
});
