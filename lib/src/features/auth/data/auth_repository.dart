import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';

/// Handles all authentication using **6-digit OTP** (one-time codes).
///
/// IMPORTANT: For the email to contain a 6-digit *code* (not a magic link), the
/// Supabase "Magic Link" email template must render `{{ .Token }}` instead of
/// `{{ .ConfirmationURL }}`. Supabase issues a 6-digit token by default.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sends a 6-digit OTP code to [email]. Creates the user if they don't exist
  /// yet (sign-up and login share the same flow).
  Future<void> sendEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Verifies the 6-digit [token] the user received by email, establishing a
  /// session on success.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Session? get currentSession => _client.auth.currentSession;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
