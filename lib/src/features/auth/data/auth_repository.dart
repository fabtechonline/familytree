import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';

/// Handles authentication: password sign-in (primary), a 6-digit email OTP
/// fallback/recovery, and registration with a password + email verification.
///
/// IMPORTANT: For the emails to contain a 6-digit *code* (not a link), the
/// Supabase "Magic Link" and "Confirm signup" templates render `{{ .Token }}`.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Primary login: email + password.
  Future<AuthResponse> signInWithPassword(String email, String password) {
    return _client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  /// Registers a new account with a password. If email confirmation is required
  /// (it is on this project), the returned session is null and a 6-digit code is
  /// emailed — verify it with [verifyEmailOtp] using [OtpType.signup].
  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email.trim(), password: password);
  }

  /// Sets/updates the password for the currently signed-in user (lets OTP-only
  /// accounts add a password).
  Future<void> setPassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  /// Sends a 6-digit OTP code to [email] (the "email me a code" fallback).
  Future<void> sendEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Verifies a 6-digit [token]. [type] is [OtpType.email] for code login or
  /// [OtpType.signup] for confirming a new registration.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.email,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: type,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Session? get currentSession => _client.auth.currentSession;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
