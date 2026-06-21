// Basic smoke test for the sign-in screen rendering in isolation.
//
// Full auth/router tests run against a configured Supabase instance and are
// added with the integration test suite in a later phase.
import 'package:familytree/src/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sign-in screen shows welcome copy and send button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );
    // Let the OTP controller's async build settle so the button leaves its
    // initial loading state.
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FamilyTree'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
