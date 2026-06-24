import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../members/application/member_providers.dart';
import '../members/domain/member.dart';
import '../members/presentation/widgets/member_avatar.dart';
import '../settings/app_settings_provider.dart';
import 'face/face_repository.dart';
import 'paywall_screen.dart';

/// Premium, on-device, opt-in "Point & Recognize" face lens.
class PointRecognizeScreen extends ConsumerStatefulWidget {
  const PointRecognizeScreen({super.key});

  @override
  ConsumerState<PointRecognizeScreen> createState() =>
      _PointRecognizeScreenState();
}

class _PointRecognizeScreenState extends ConsumerState<PointRecognizeScreen> {
  bool _busy = false;
  String? _status;
  Member? _result;
  String? _resultNote;

  Future<void> _enableConsent(String familyId) async {
    setState(() => _busy = true);
    try {
      await ref.read(faceRepositoryProvider).setConsent(familyId, true);
      ref.invalidate(myFamiliesProvider);
    } catch (e) {
      _snack('Could not enable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _index(String familyId, List<Member> members) async {
    setState(() {
      _busy = true;
      _status = 'Indexing faces…';
    });
    try {
      final n = await ref.read(faceRepositoryProvider).indexFamily(familyId, members);
      _snack('Indexed $n member${n == 1 ? '' : 's'} with a clear face photo.');
    } catch (e) {
      _snack('Indexing failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _recognize(String familyId, List<Member> members) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _busy = true;
      _status = 'Looking…';
      _result = null;
      _resultNote = null;
    });
    try {
      final match = await ref.read(faceRepositoryProvider).matchFile(familyId, picked.path);
      if (match == null) {
        _resultNote = 'No face detected, or no one is indexed yet.';
      } else if (match.isConfident || match.isMaybe) {
        _result = members.where((m) => m.id == match.memberId).firstOrNull;
        _resultNote = match.isConfident ? 'Match found' : 'Possible match';
      } else {
        _resultNote = 'No confident match in this family.';
      }
    } catch (e) {
      _resultNote = 'Recognition failed: $e';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final settings = ref.watch(publicSettingsProvider).value;
    if (settings != null && !settings.faceRecognition) {
      return Scaffold(
        appBar: AppBar(title: const Text('Point & Recognize')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This feature is temporarily unavailable.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!isPremium) {
      return const PaywallScreen(
        feature: 'Point & Recognize',
        blurb:
            'Aim your camera at a relative and the app recognises them from your tree.',
      );
    }

    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider(family.id)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Point & Recognize')),
      body: !family.faceRecognitionEnabled
          ? _Consent(
              isAdmin: family.myRole.isAdmin,
              busy: _busy,
              onEnable: () => _enableConsent(family.id),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
              children: [
                Text('On-device · matches only within ${family.name}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                if (family.myRole.canEdit)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _index(family.id, members),
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: const Text('Index family faces'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _recognize(family.id, members),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Recognise a face'),
                ),
                if (_busy) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Column(children: [
                      const CircularProgressIndicator(),
                      if (_status != null) ...[
                        const SizedBox(height: 8),
                        Text(_status!),
                      ],
                    ]),
                  ),
                ],
                if (!_busy && (_result != null || _resultNote != null)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ResultCard(
                    member: _result,
                    note: _resultNote,
                    onOpen: _result == null
                        ? null
                        : () => context.push('/profile/${_result!.id}'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tip: add clear, front-facing photos to members, then tap '
                  '"Index family faces" so the lens can recognise them.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent(
      {required this.isAdmin, required this.busy, required this.onEnable});
  final bool isAdmin;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.privacy_tip_rounded,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Turn on Point & Recognize',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This uses face recognition, which is sensitive biometric data. '
                'It runs entirely on this device, matches only within your family, '
                'and is never shared. You can turn it off anytime, which deletes '
                'all stored face data for this family.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isAdmin)
                FilledButton(
                  onPressed: busy ? null : onEnable,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('I consent — enable'),
                )
              else
                Text('Ask a family admin to enable this feature.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.member, required this.note, this.onOpen});
  final Member? member;
  final String? note;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            if (member != null) ...[
              MemberAvatar(member: member!, radius: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(member!.fullName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if (note != null)
                Text(note!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                  onPressed: onOpen, child: const Text('Open profile')),
            ] else
              Text(note ?? 'No result',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
