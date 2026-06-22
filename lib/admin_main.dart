// Separate entry point for the Super-Admin web console.
//
// Run with:
//   flutter run -d chrome --dart-define-from-file=env.json -t lib/admin_main.dart
//
// This is the platform owner's console. It manages accounts, subscriptions and
// the audit log only — it has no access to any family's tree content.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/admin/presentation/admin_app.dart';
import 'src/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  runApp(const ProviderScope(child: AdminApp()));
}
