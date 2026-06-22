import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/app_config.dart';
import 'src/router/app_router.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Modern publishable key (safe for clients). Legacy anon/service_role keys
    // are disabled on this project; the secret key is never used here.
    publishableKey: AppConfig.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: RizaApp()));
}

class RizaApp extends ConsumerWidget {
  const RizaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Riza',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
