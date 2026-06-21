import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Drives the OTP sign-in flow: requesting a code and verifying it.
///
/// The async [state] reflects in-flight network calls so the UI can show
/// spinners and surface errors. UI navigation (email step -> code step ->
/// home) is driven by the router reacting to auth state, not by this notifier.
class OtpController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Requests a 6-digit code be emailed to [email].
  Future<bool> sendCode(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendEmailOtp(email));
    return !state.hasError;
  }

  /// Verifies the [code] for [email]. On success the auth state stream emits a
  /// signed-in session and the router redirects.
  Future<bool> verifyCode({required String email, required String code}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.verifyEmailOtp(email: email, token: code),
    );
    return !state.hasError;
  }
}

final otpControllerProvider =
    AsyncNotifierProvider<OtpController, void>(OtpController.new);
