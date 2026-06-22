// Basic smoke test for the sign-in screen rendering in isolation.
//
// Full auth/router tests run against a configured Supabase instance and are
// added with the integration test suite in a later phase.
import 'package:riza/src/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sign-in screen shows password login with code fallback',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email me a code instead'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    // Email + password fields.
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
