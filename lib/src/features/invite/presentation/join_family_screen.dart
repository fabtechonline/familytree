import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

/// Join an existing family via an invite code (typed or scanned from a QR).
class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final _codeController = TextEditingController();
  InvitePreview? _preview;
  bool _loading = false;
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Accepts a plain code or a URL containing `code=...`.
  String _normalize(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'code=([A-Za-z0-9]+)').firstMatch(trimmed);
    return (match?.group(1) ?? trimmed).toUpperCase();
  }

  Future<void> _lookup([String? scanned]) async {
    final code = _normalize(scanned ?? _codeController.text);
    if (code.isEmpty) return;
    _codeController.text = code;
    setState(() {
      _loading = true;
      _preview = null;
    });
    try {
      final preview = await ref.read(inviteRepositoryProvider).previewInvite(code);
      if (!mounted) return;
      setState(() => _loading = false);
      if (preview == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No family found for that code.')));
      } else {
        setState(() => _preview = preview);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not look up code: $e')));
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (code != null && code.isNotEmpty) {
      await _lookup(code);
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final Family family = await ref
          .read(inviteRepositoryProvider)
          .joinWithCode(_normalize(_codeController.text));
      ref.invalidate(myFamiliesProvider);
      ref.read(selectedFamilyIdProvider.notifier).select(family.id);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not join: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join a family')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          Icon(Icons.group_add_rounded,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('Enter your invite code',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text('Ask a family admin for a code, or scan their QR.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: 4, fontSize: 20),
            decoration: const InputDecoration(hintText: 'INVITE CODE'),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan QR'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : () => _lookup(),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Find family'),
                ),
              ),
            ],
          ),
          if (_preview != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _PreviewCard(
              preview: _preview!,
              joining: _joining,
              onJoin: _preview!.valid ? _join : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.joining,
    required this.onJoin,
  });

  final InvitePreview preview;
  final bool joining;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel =
        preview.role.name[0].toUpperCase() + preview.role.name.substring(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.family_restroom_rounded,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(preview.familyName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (preview.valid)
              Text('You\'ll join as $roleLabel',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              Text('This invite has expired',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: joining ? null : onJoin,
              child: joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Join family'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen QR scanner; pops with the decoded string.
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan invite QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              _handled = true;
              Navigator.of(context).pop(value);
              return;
            }
          }
        },
      ),
    );
  }
}
