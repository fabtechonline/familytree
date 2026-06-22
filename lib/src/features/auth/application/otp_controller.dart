import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Drives auth flows: password sign-in, registration, the emailed-code
/// fallback, and setting a password. The async [state] reflects in-flight calls
/// so the UI can show spinners; navigation is driven by the router reacting to
/// the auth state.
class OtpController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Password login. Returns null on success, or an error message.
  Future<String?> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _repo.signInWithPassword(email, password);
      state = const AsyncData(null);
      return null;
    } on AuthException catch (e) {
      state = const AsyncData(null);
      return e.message;
    } catch (e) {
      state = const AsyncData(null);
      return '$e';
    }
  }

  /// Registers with a password. Returns (error, needsConfirm): on success
  /// error is null and needsConfirm tells whether an email code must be entered.
  Future<({String? error, bool needsConfirm})> register(
      String email, String password) async {
    state = const AsyncLoading();
    try {
      final res = await _repo.signUp(email, password);
      state = const AsyncData(null);
      return (error: null, needsConfirm: res.session == null);
    } on AuthException catch (e) {
      state = const AsyncData(null);
      return (error: e.message, needsConfirm: false);
    } catch (e) {
      state = const AsyncData(null);
      return (error: '$e', needsConfirm: false);
    }
  }

  /// Sets/updates the signed-in user's password. Returns null on success.
  Future<String?> setPassword(String password) async {
    state = const AsyncLoading();
    try {
      await _repo.setPassword(password);
      state = const AsyncData(null);
      return null;
    } on AuthException catch (e) {
      state = const AsyncData(null);
      return e.message;
    } catch (e) {
      state = const AsyncData(null);
      return '$e';
    }
  }

  /// Requests a 6-digit code be emailed to [email] (code fallback).
  Future<bool> sendCode(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendEmailOtp(email));
    return !state.hasError;
  }

  /// Verifies the [code] for [email]. [signup] uses the registration token type.
  Future<bool> verifyCode({
    required String email,
    required String code,
    bool signup = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.verifyEmailOtp(
        email: email,
        token: code,
        type: signup ? OtpType.signup : OtpType.email,
      ),
    );
    return !state.hasError;
  }
}

final otpControllerProvider =
    AsyncNotifierProvider<OtpController, void>(OtpController.new);
