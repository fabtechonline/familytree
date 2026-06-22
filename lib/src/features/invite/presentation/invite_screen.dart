import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../members/application/member_providers.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

/// Admin screen to invite relatives: pick a role, generate a code, then share
/// the code or its QR.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  FamilyRole _role = FamilyRole.contributor;
  String? _targetMemberId; // for "relative" invites
  Invitation? _invite;
  bool _generating = false;

  // Roles that can be granted via an invite (admin is granted deliberately).
  static const _grantableRoles = [
    FamilyRole.admin,
    FamilyRole.editor,
    FamilyRole.contributor,
    FamilyRole.relative,
    FamilyRole.viewer,
  ];

  String get _roleBlurb => switch (_role) {
        FamilyRole.admin => 'Full control: manage members, settings and billing.',
        FamilyRole.editor => 'Can add and edit members and relationships.',
        FamilyRole.contributor => 'Can suggest changes for an admin to approve.',
        FamilyRole.relative =>
          'Can view the family and edit only their own profile.',
        FamilyRole.viewer => 'Can view the tree but not make changes.',
      };

  Future<void> _generate(String familyId) async {
    if (_role == FamilyRole.relative && _targetMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick which person this invite is for.')));
      return;
    }
    setState(() => _generating = true);
    try {
      final invite = await ref.read(inviteRepositoryProvider).createInvitation(
            familyId,
            _role,
            targetMemberId:
                _role == FamilyRole.relative ? _targetMemberId : null,
          );
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not create invite: $e')));
    }
  }

  String _shareText(String familyName) {
    final code = _invite!.code;
    return 'Join the $familyName family tree on FamilyTree!\n\n'
        'Open the app, tap "Join a family", and enter this code:\n$code';
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite family')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Choose a role for the people you invite',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _grantableRoles.map((r) {
              return ChoiceChip(
                label: Text(_roleLabel(r)),
                selected: _role == r,
                onSelected: (_) => setState(() {
                  _role = r;
                  _invite = null; // re-generate for the new role
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_roleBlurb,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (_role == FamilyRole.relative) ...[
            const SizedBox(height: AppSpacing.md),
            _MemberToClaimPicker(
              familyId: family.id,
              selectedId: _targetMemberId,
              onChanged: (id) => setState(() {
                _targetMemberId = id;
                _invite = null;
              }),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_invite == null)
            FilledButton.icon(
              onPressed: _generating ? null : () => _generate(family.id),
              icon: _generating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.qr_code_2_rounded),
              label: const Text('Generate invite'),
            )
          else
            _InviteResult(
              invite: _invite!,
              familyName: family.name,
              roleLabel: _roleLabel(_invite!.role),
              onShare: () => SharePlus.instance
                  .share(ShareParams(text: _shareText(family.name))),
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: _invite!.code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied')));
              },
              onNew: () => setState(() => _invite = null),
            ),
        ],
      ),
    );
  }

  static String _roleLabel(FamilyRole r) =>
      r.name[0].toUpperCase() + r.name.substring(1);
}

class _InviteResult extends StatelessWidget {
  const _InviteResult({
    required this.invite,
    required this.familyName,
    required this.roleLabel,
    required this.onShare,
    required this.onCopy,
    required this.onNew,
  });

  final Invitation invite;
  final String familyName;
  final String roleLabel;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text('Invite as $roleLabel',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: invite.code,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              invite.code,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Relatives can scan this QR or enter the code to join.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onNew, child: const Text('New invite')),
          ],
        ),
      ),
    );
  }
}

/// Lets the admin pick which existing person a "relative" invite is for, so the
/// joiner is auto-linked to that profile.
class _MemberToClaimPicker extends ConsumerWidget {
  const _MemberToClaimPicker({
    required this.familyId,
    required this.selectedId,
    required this.onChanged,
  });
  final String familyId;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(familyId)).value ?? const [];
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Whose profile is this invite for?',
      ),
      items: members
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(m.fullName, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
