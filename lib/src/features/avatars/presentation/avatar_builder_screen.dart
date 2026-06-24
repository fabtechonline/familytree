import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../members/application/member_providers.dart';
import '../../members/data/member_repository.dart';
import '../../members/domain/member.dart';
import '../../settings/app_settings_provider.dart';
import '../data/generate_avatar.dart';
import '../dicebear.dart';

/// Build an illustrated (DiceBear) avatar for a member. Free for everyone;
/// "Generate from photo" (Claude vision) is Premium.
class AvatarBuilderScreen extends ConsumerStatefulWidget {
  const AvatarBuilderScreen({super.key, required this.member});
  final Member member;

  @override
  ConsumerState<AvatarBuilderScreen> createState() => _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends ConsumerState<AvatarBuilderScreen> {
  late Map<String, dynamic> _config;
  bool _busy = false;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    _config = widget.member.avatarConfig != null
        ? Map<String, dynamic>.from(widget.member.avatarConfig!)
        : {
            'style': avatarStyle,
            'seed': widget.member.id.substring(0, 8),
            'options': <String, dynamic>{},
          };
    _config['options'] ??= <String, dynamic>{};
  }

  Map<String, dynamic> get _opt => (_config['options'] as Map).cast<String, dynamic>();
  void _setOpt(String k, dynamic v) => setState(() => _config['options'] = {..._opt, k: v});

  Future<void> _save(String familyId) async {
    setState(() => _busy = true);
    try {
      await ref.read(memberRepositoryProvider).setAvatarConfig(widget.member.id, _config);
      invalidateFamilyData(ref, familyId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Future<void> _remove(String familyId) async {
    setState(() => _busy = true);
    await ref.read(memberRepositoryProvider).setAvatarConfig(widget.member.id, null);
    invalidateFamilyData(ref, familyId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _generateFromPhoto() async {
    setState(() => _aiBusy = true);
    try {
      final cfg = await generateAvatarFromPhoto(
          ref.read(supabaseClientProvider), widget.member.id);
      setState(() {
        _config = cfg;
        _config['options'] ??= <String, dynamic>{};
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI generation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    final isPremium = family?.subscriptionTier == SubscriptionTier.premium;
    final aiOn = ref.watch(publicSettingsProvider).value?.aiAvatar != false;
    final canAi = isPremium && aiOn;
    final hasPhoto = (widget.member.photoUrl ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Illustrated avatar')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.seed.withValues(alpha: 0.1),
              backgroundImage: NetworkImage(dicebearUrl(_config, size: 320)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() =>
                    _config['seed'] = math.Random().nextInt(1 << 32).toRadixString(36)),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
              ),
              if (hasPhoto) ...[
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: (canAi && !_aiBusy) ? _generateFromPhoto : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(_aiBusy ? 'Analyzing…' : 'From photo'),
                ),
              ],
            ],
          ),
          if (hasPhoto && !canAi)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  isPremium
                      ? 'AI avatars are temporarily unavailable.'
                      : 'AI “generate from photo” is a Premium feature.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: AppSpacing.lg),

          _label('Skin tone'),
          _swatches(skinTones, _opt['skinColor'] as String?, (c) => _setOpt('skinColor', c)),
          const SizedBox(height: AppSpacing.md),
          _label('Hair colour'),
          _swatches(hairColors, _opt['hairColor'] as String?, (c) => _setOpt('hairColor', c)),
          const SizedBox(height: AppSpacing.md),
          _label('Hair style'),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < hairStyles.length; i++)
                ChoiceChip(
                  label: Text('${i + 1}'),
                  selected: _opt['hair'] == hairStyles[i],
                  onSelected: (_) => _setOpt('hair', hairStyles[i]),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Glasses'),
            value: _opt['glassesProbability'] == 100,
            onChanged: (v) => _setOpt('glassesProbability', v ? 100 : 0),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy || family == null ? null : () => _save(family.id),
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Use this avatar'),
          ),
          if (widget.member.avatarConfig != null && family != null)
            TextButton(
              onPressed: _busy ? null : () => _remove(family.id),
              child: const Text('Remove avatar'),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  Widget _swatches(List<String> colors, String? selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onTap(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(int.parse('FF$c', radix: 16)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == c ? AppColors.seed : Colors.black12,
                  width: selected == c ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
