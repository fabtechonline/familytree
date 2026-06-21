import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../application/member_providers.dart';
import '../data/member_repository.dart';
import '../domain/member.dart';
import '../domain/relationship.dart';
import 'widgets/member_avatar.dart';

/// How a brand-new member links to an existing one. Each option also implies
/// the new member's gender and which graph edge(s) to create.
enum _LinkKind {
  wifeOf,
  husbandOf,
  sonOf,
  daughterOf,
  brotherOf,
  sisterOf,
  none;

  String get label => switch (this) {
        _LinkKind.wifeOf => 'Wife of',
        _LinkKind.husbandOf => 'Husband of',
        _LinkKind.sonOf => 'Son of',
        _LinkKind.daughterOf => 'Daughter of',
        _LinkKind.brotherOf => 'Brother of',
        _LinkKind.sisterOf => 'Sister of',
        _LinkKind.none => 'No link',
      };

  /// Gender implied for the new member, or null for [none].
  String? get impliedGender => switch (this) {
        _LinkKind.wifeOf || _LinkKind.daughterOf || _LinkKind.sisterOf =>
          'female',
        _LinkKind.husbandOf || _LinkKind.sonOf || _LinkKind.brotherOf => 'male',
        _LinkKind.none => null,
      };
}

/// A selectable anchor in the relationship picker: either a single person or a
/// married couple (shown together on one line).
class _AnchorOption {
  const _AnchorOption({
    required this.key,
    required this.label,
    required this.memberIds,
    required this.primary,
    this.secondary,
  });

  final String key;
  final String label;
  final List<String> memberIds;
  final Member primary;
  final Member? secondary;

  bool get isCouple => secondary != null;
}

/// Add or edit a member. When [memberId] is null this is an "add" flow that can
/// also create one relationship to an existing member.
class MemberEditScreen extends ConsumerStatefulWidget {
  const MemberEditScreen({super.key, this.memberId});

  final String? memberId;

  bool get isEditing => memberId != null;

  @override
  ConsumerState<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends ConsumerState<MemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _maidenName = TextEditingController();
  final _birthPlace = TextEditingController();
  final _bio = TextEditingController();

  String? _gender;
  bool _isLiving = true;
  DateTime? _birthDate;
  DateTime? _deathDate;

  /// Newly-picked photo bytes (not yet uploaded), and the existing photo URL.
  Uint8List? _pickedBytes;
  String? _photoUrl;

  _LinkKind _linkKind = _LinkKind.sonOf;

  /// The selected anchor option key and the member id(s) it resolves to (one
  /// for a single person, two for a married couple).
  String? _anchorKey;
  List<String> _anchorIds = const [];

  bool _submitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _maidenName.dispose();
    _birthPlace.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _hydrateFrom(Member m) {
    _firstName.text = m.firstName;
    _lastName.text = m.lastName ?? '';
    _maidenName.text = m.maidenName ?? '';
    _birthPlace.text = m.birthPlace ?? '';
    _bio.text = m.bio ?? '';
    _gender = m.gender;
    _isLiving = m.isLiving;
    _birthDate = m.birthDate;
    _deathDate = m.deathDate;
    _photoUrl = m.photoUrl;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pickedBytes = bytes);
  }

  Future<void> _pickDate({required bool isBirth}) async {
    final now = DateTime.now();
    final initial = (isBirth ? _birthDate : _deathDate) ?? DateTime(now.year - 30);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1700),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isBirth) {
          _birthDate = picked;
        } else {
          _deathDate = picked;
        }
      });
    }
  }

  Future<void> _save(String familyId, List<Member> existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = ref.read(memberRepositoryProvider);

    var draft = Member(
      id: widget.memberId ?? '',
      familyId: familyId,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
      maidenName:
          _maidenName.text.trim().isEmpty ? null : _maidenName.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      deathDate: _isLiving ? null : _deathDate,
      isLiving: _isLiving,
      birthPlace:
          _birthPlace.text.trim().isEmpty ? null : _birthPlace.text.trim(),
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      photoUrl: _photoUrl,
    );

    try {
      if (widget.isEditing) {
        // Upload first (member id already exists) so the URL persists with the
        // rest of the edits in a single update.
        if (_pickedBytes != null) {
          final url = await repo.uploadMemberPhoto(
              familyId: familyId,
              memberId: widget.memberId!,
              bytes: _pickedBytes!);
          draft = draft.copyWith(photoUrl: url);
        }
        await repo.updateMember(draft);
      } else {
        final created = await repo.addMember(draft);
        // New member needs an id before we can upload to its storage path.
        if (_pickedBytes != null) {
          final url = await repo.uploadMemberPhoto(
              familyId: familyId, memberId: created.id, bytes: _pickedBytes!);
          await repo.updateMember(created.copyWith(photoUrl: url));
        }
        await _createLinkIfNeeded(repo, familyId, created.id);
      }
      invalidateFamilyData(ref, familyId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  /// Builds the anchor list: every person individually, then each married
  /// couple combined onto one line (e.g. "John & Mary Smith").
  List<_AnchorOption> _buildAnchorOptions(
      List<Member> anchors, List<Relationship> relationships) {
    final byId = {for (final m in anchors) m.id: m};
    final options = <_AnchorOption>[
      for (final m in anchors)
        _AnchorOption(
            key: m.id, label: m.fullName, memberIds: [m.id], primary: m),
    ];

    final seen = <String>{};
    for (final r in relationships) {
      if (!r.isUnion) continue;
      final a = byId[r.fromMember];
      final b = byId[r.toMember];
      if (a == null || b == null) continue;
      final pairKey =
          a.id.compareTo(b.id) < 0 ? '${a.id}+${b.id}' : '${b.id}+${a.id}';
      if (!seen.add(pairKey)) continue;
      options.add(_AnchorOption(
        key: 'couple:$pairKey',
        label: '${a.firstName} & ${b.fullName}',
        memberIds: [a.id, b.id],
        primary: a,
        secondary: b,
      ));
    }
    return options;
  }

  Future<void> _createLinkIfNeeded(
      MemberRepository repo, String familyId, String newId) async {
    final anchors = _anchorIds;
    if (_linkKind == _LinkKind.none || anchors.isEmpty) return;

    switch (_linkKind) {
      // New member is the spouse of the anchor (use the first if a couple was
      // somehow selected — spouse links are 1:1).
      case _LinkKind.wifeOf:
      case _LinkKind.husbandOf:
        await repo.addRelationship(
            familyId: familyId,
            fromMember: anchors.first,
            toMember: newId,
            type: RelType.spouse);
      // New member is a child of the anchor(s) — link to both parents if a
      // couple was selected.
      case _LinkKind.sonOf:
      case _LinkKind.daughterOf:
        for (final parentId in anchors) {
          await repo.addRelationship(
              familyId: familyId,
              fromMember: parentId,
              toMember: newId,
              type: RelType.parent);
        }
      // New member is a sibling of the anchor: share the anchor's parents.
      case _LinkKind.brotherOf:
      case _LinkKind.sisterOf:
        await repo.linkSiblingByParents(
            familyId: familyId, newMemberId: newId, siblingOfId: anchors.first);
      case _LinkKind.none:
        break;
    }
  }

  Future<void> _confirmDelete(String familyId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete member?'),
        content: const Text(
            'This removes the person and their relationships. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(memberRepositoryProvider).deleteMember(widget.memberId!);
      invalidateFamilyData(ref, familyId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final membersAsync = ref.watch(membersProvider(family.id));
    final members = membersAsync.value ?? const <Member>[];
    final relationships =
        ref.watch(relationshipsProvider(family.id)).value ?? const [];

    // Hydrate fields once when editing an existing member.
    if (widget.isEditing && !_initialized) {
      final existing = members.where((m) => m.id == widget.memberId).firstOrNull;
      if (existing != null) {
        _hydrateFrom(existing);
        _initialized = true;
      }
    }

    // Candidate anchors for linking (exclude the member being edited): each
    // single person, plus married couples shown together on one line.
    final anchors = members.where((m) => m.id != widget.memberId).toList();
    final anchorOptions = _buildAnchorOptions(anchors, relationships);
    if (_anchorKey == null && anchorOptions.isNotEmpty) {
      _anchorKey = anchorOptions.first.key;
      _anchorIds = anchorOptions.first.memberIds;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit member' : 'Add member'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(family.id),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Extra bottom padding so the save button clears the device
          // navigation bar / gesture area.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: _PhotoHeader(
                pickedBytes: _pickedBytes,
                photoUrl: _photoUrl,
                onTap: _pickPhoto,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'First name *',
                  prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'First name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _maidenName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Maiden name (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            _GenderPicker(
              value: _gender,
              onChanged: (g) => setState(() => _gender = g),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Living'),
              value: _isLiving,
              onChanged: (v) => setState(() => _isLiving = v),
            ),
            _DateField(
              label: 'Date of birth',
              value: _birthDate,
              onTap: () => _pickDate(isBirth: true),
              onClear: () => setState(() => _birthDate = null),
            ),
            if (!_isLiving) ...[
              const SizedBox(height: AppSpacing.sm),
              _DateField(
                label: 'Date of death',
                value: _deathDate,
                onTap: () => _pickDate(isBirth: false),
                onClear: () => setState(() => _deathDate = null),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _birthPlace,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Birthplace',
                  prefixIcon: Icon(Icons.place_outlined)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bio,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Bio / notes', alignLabelWithHint: true),
            ),

            // Relationship picker only when adding and there's someone to link to.
            if (!widget.isEditing && anchorOptions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _RelationshipPicker(
                kind: _linkKind,
                selectedKey: _anchorKey,
                options: anchorOptions,
                onKindChanged: (k) => setState(() {
                  _linkKind = k;
                  // Auto-fill gender implied by the relationship.
                  final g = k.impliedGender;
                  if (g != null) _gender = g;
                }),
                onAnchorChanged: (option) => setState(() {
                  _anchorKey = option.key;
                  _anchorIds = option.memberIds;
                }),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submitting ? null : () => _save(family.id, members),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(widget.isEditing ? 'Save changes' : 'Add member'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.pickedBytes,
    required this.photoUrl,
    required this.onTap,
  });

  final Uint8List? pickedBytes;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    ImageProvider? image;
    if (pickedBytes != null) {
      image = MemoryImage(pickedBytes!);
    } else if ((photoUrl ?? '').isNotEmpty) {
      image = NetworkImage(photoUrl!);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: color.withValues(alpha: 0.12),
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.add_a_photo_rounded, size: 36, color: color)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: Icon(Icons.edit_rounded,
                  size: 16, color: theme.colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.sm,
        children: _options.entries.map((e) {
          final selected = value == e.key;
          return ChoiceChip(
            label: Text(e.value),
            selected: selected,
            onSelected: (_) => onChanged(selected ? null : e.key),
          );
        }).toList(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Not set'
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: onClear),
        ),
        child: Text(text),
      ),
    );
  }
}

class _RelationshipPicker extends StatelessWidget {
  const _RelationshipPicker({
    required this.kind,
    required this.selectedKey,
    required this.options,
    required this.onKindChanged,
    required this.onAnchorChanged,
  });

  final _LinkKind kind;
  final String? selectedKey;
  final List<_AnchorOption> options;
  final ValueChanged<_LinkKind> onKindChanged;
  final ValueChanged<_AnchorOption> onAnchorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected =
        options.where((o) => o.key == selectedKey).firstOrNull ?? options.first;
    final anchorName = selected.isCouple
        ? '${selected.primary.firstName} & ${selected.secondary!.firstName}'
        : selected.primary.firstName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are they related?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _LinkKind.values.map((k) {
                return ChoiceChip(
                  label: Text(k.label),
                  selected: kind == k,
                  onSelected: (_) => onKindChanged(k),
                );
              }).toList(),
            ),
            if (kind != _LinkKind.none) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('This person is the ${kind.label.toLowerCase()} $anchorName',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _AnchorAvatars(option: selected),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selected.key,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Related member'),
                      items: options
                          .map((o) => DropdownMenuItem(
                                value: o.key,
                                child: Row(
                                  children: [
                                    if (o.isCouple)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.favorite_rounded,
                                            size: 14,
                                            color: AppColors.accentCoral),
                                      ),
                                    Expanded(
                                      child: Text(o.label,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (key) {
                        if (key == null) return;
                        final option =
                            options.firstWhere((o) => o.key == key);
                        onAnchorChanged(option);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows one avatar for a single anchor, or two overlapping avatars for a
/// married couple.
class _AnchorAvatars extends StatelessWidget {
  const _AnchorAvatars({required this.option});
  final _AnchorOption option;

  @override
  Widget build(BuildContext context) {
    if (!option.isCouple) {
      return MemberAvatar(member: option.primary, radius: 18);
    }
    return SizedBox(
      width: 52,
      height: 36,
      child: Stack(
        children: [
          MemberAvatar(member: option.primary, radius: 18),
          Positioned(
            left: 16,
            child: CircleAvatar(
              radius: 19,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: MemberAvatar(member: option.secondary!, radius: 18),
            ),
          ),
        ],
      ),
    );
  }
}
