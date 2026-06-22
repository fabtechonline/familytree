import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_providers.dart';

/// Password login for the platform owner. (The consumer app uses OTP; the admin
/// console uses a password so it can be a distinct, deliberate login.)
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      // The gate re-evaluates on the new session.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.shield_moon_rounded,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Riza Admin',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Platform owner console',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            (v ?? '').contains('@') ? null : 'Enter your email',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder()),
                        onFieldSubmitted: (_) => _signIn(),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Enter your password' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _signIn,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
