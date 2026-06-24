import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../suggestions/data/suggestion_repository.dart';
import '../application/member_providers.dart';
import '../data/member_repository.dart';
import '../domain/member.dart';
import '../domain/relationship.dart';
import '../../avatars/presentation/avatar_builder_screen.dart';
import '../../map/data/geocoding.dart';
import 'face_capture_screen.dart';
import 'widgets/member_avatar.dart';

/// The semantic category of a relationship, independent of gender.
enum _RelCategory { spouse, parent, child, sibling, none }

/// How a brand-new member links to an existing one. Each option also implies
/// the new member's gender and which graph edge(s) to create.
enum _LinkKind {
  husbandOf,
  wifeOf,
  fatherOf,
  motherOf,
  sonOf,
  daughterOf,
  brotherOf,
  sisterOf,
  none;

  String get label => switch (this) {
        _LinkKind.husbandOf => 'Husband of',
        _LinkKind.wifeOf => 'Wife of',
        _LinkKind.fatherOf => 'Father of',
        _LinkKind.motherOf => 'Mother of',
        _LinkKind.sonOf => 'Son of',
        _LinkKind.daughterOf => 'Daughter of',
        _LinkKind.brotherOf => 'Brother of',
        _LinkKind.sisterOf => 'Sister of',
        _LinkKind.none => 'No link',
      };

  /// Gender implied for the new member, or null for [none].
  String? get impliedGender => switch (this) {
        _LinkKind.wifeOf ||
        _LinkKind.motherOf ||
        _LinkKind.daughterOf ||
        _LinkKind.sisterOf =>
          'female',
        _LinkKind.husbandOf ||
        _LinkKind.fatherOf ||
        _LinkKind.sonOf ||
        _LinkKind.brotherOf =>
          'male',
        _LinkKind.none => null,
      };

  _RelCategory get category => switch (this) {
        _LinkKind.husbandOf || _LinkKind.wifeOf => _RelCategory.spouse,
        _LinkKind.fatherOf || _LinkKind.motherOf => _RelCategory.parent,
        _LinkKind.sonOf || _LinkKind.daughterOf => _RelCategory.child,
        _LinkKind.brotherOf || _LinkKind.sisterOf => _RelCategory.sibling,
        _LinkKind.none => _RelCategory.none,
      };

  /// The same relationship category expressed for a given gender, so switching
  /// gender keeps the user's intent (e.g. "Son of" -> "Daughter of").
  static _LinkKind forCategoryGender(_RelCategory cat, bool male) {
    return switch (cat) {
      _RelCategory.spouse => male ? _LinkKind.husbandOf : _LinkKind.wifeOf,
      _RelCategory.parent => male ? _LinkKind.fatherOf : _LinkKind.motherOf,
      _RelCategory.child => male ? _LinkKind.sonOf : _LinkKind.daughterOf,
      _RelCategory.sibling => male ? _LinkKind.brotherOf : _LinkKind.sisterOf,
      _RelCategory.none => _LinkKind.none,
    };
  }

  /// Options to show for the currently chosen [gender]. When no specific gender
  /// is chosen, all options are shown.
  static List<_LinkKind> forGender(String? gender) {
    if (gender == 'male') {
      return [husbandOf, fatherOf, sonOf, brotherOf, none];
    }
    if (gender == 'female') {
      return [wifeOf, motherOf, daughterOf, sisterOf, none];
    }
    return _LinkKind.values;
  }
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
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _occupation = TextEditingController();

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
  String? _anchorLabel;

  bool _submitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _maidenName.dispose();
    _birthPlace.dispose();
    _bio.dispose();
    _phone.dispose();
    _address.dispose();
    _occupation.dispose();
    super.dispose();
  }

  void _hydrateFrom(Member m) {
    _firstName.text = m.firstName;
    _lastName.text = m.lastName ?? '';
    _maidenName.text = m.maidenName ?? '';
    _birthPlace.text = m.birthPlace ?? '';
    _bio.text = m.bio ?? '';
    _phone.text = m.phone ?? '';
    _address.text = m.address ?? '';
    _occupation.text = m.occupation ?? '';
    _gender = m.gender;
    _isLiving = m.isLiving;
    _birthDate = m.birthDate;
    _deathDate = m.deathDate;
    _photoUrl = m.photoUrl;
    // Keep the default "Add relationship" option consistent with this member's
    // gender so it appears among the gender-filtered chips.
    if (m.gender == 'male' || m.gender == 'female') {
      _linkKind =
          _LinkKind.forCategoryGender(_RelCategory.child, m.gender == 'male');
    }
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
              subtitle: const Text('With a face guide'),
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
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      // Custom camera with an oval face guide; returns processed bytes.
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
      );
      if (bytes == null || !mounted) return;
      setState(() => _pickedBytes = bytes);
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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

  /// Member fields for a contributor suggestion payload (snake_case to match
  /// the columns the apply RPC writes).
  Map<String, dynamic> _suggestionPayload() {
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    String? d(DateTime? v) => v?.toIso8601String().split('T').first;
    return {
      'first_name': _firstName.text.trim(),
      'last_name': clean(_lastName),
      'maiden_name': clean(_maidenName),
      'gender': _gender,
      'birth_date': d(_birthDate),
      'death_date': _isLiving ? null : d(_deathDate),
      'is_living': _isLiving,
      'birth_place': clean(_birthPlace),
      'bio': clean(_bio),
      'phone': clean(_phone),
      'address': clean(_address),
      'occupation': clean(_occupation),
    };
  }

  Future<void> _submitSuggestion(String familyId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = ref.read(suggestionRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.suggestMemberEdit(
            familyId: familyId,
            targetMemberId: widget.memberId!,
            payload: _suggestionPayload());
      } else {
        await repo.suggestMemberAdd(
            familyId: familyId, payload: _suggestionPayload());
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sent for approval'),
          content: const Text(
              'Your suggestion was sent to the family admins. It will appear once approved.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  Future<void> _save(String familyId, List<Member> existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = ref.read(memberRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    // Geocode home/birthplace for the Family Map (best effort). Preserve existing
    // coords unless the place text changed; clear them if the field was emptied.
    final current =
        existing.where((m) => m.id == widget.memberId).firstOrNull;
    final addr = _address.text.trim();
    final birthPlace = _birthPlace.text.trim();
    double? homeLat = current?.homeLat, homeLng = current?.homeLng;
    double? birthLat = current?.birthLat, birthLng = current?.birthLng;
    if (addr.isEmpty) {
      homeLat = null;
      homeLng = null;
    } else if (addr != (current?.address ?? '')) {
      final g = await geocode(addr);
      if (g != null) {
        homeLat = g.lat;
        homeLng = g.lng;
      }
    }
    if (birthPlace.isEmpty) {
      birthLat = null;
      birthLng = null;
    } else if (birthPlace != (current?.birthPlace ?? '')) {
      final g = await geocode(birthPlace);
      if (g != null) {
        birthLat = g.lat;
        birthLng = g.lng;
      }
    }

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
      birthPlace: birthPlace.isEmpty ? null : birthPlace,
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      address: addr.isEmpty ? null : addr,
      occupation:
          _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      homeLat: homeLat,
      homeLng: homeLng,
      birthLat: birthLat,
      birthLng: birthLng,
      photoUrl: _photoUrl,
    );

    try {
      String? warn;
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
        warn = await _createLinkIfNeeded(repo, familyId, created.id);
      }
      invalidateFamilyData(ref, familyId);
      if (!mounted) return;
      context.pop();
      if (warn != null) {
        messenger.showSnackBar(SnackBar(content: Text(warn)));
      }
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

  Future<String?> _createLinkIfNeeded(
      MemberRepository repo, String familyId, String newId) {
    return _applyLink(repo, familyId, newId, _linkKind, _anchorIds);
  }

  /// Applies the relationship described by [kind] between [memberId] and the
  /// selected [anchorIds]. Reused by both the add flow (on save) and the edit
  /// flow ("Add relationship"). Returns null on success, or a warning message
  /// when nothing could be linked (so the caller doesn't show a false success).
  Future<String?> _applyLink(MemberRepository repo, String familyId,
      String memberId, _LinkKind kind, List<String> anchorIds) async {
    if (kind == _LinkKind.none || anchorIds.isEmpty) return null;

    switch (kind) {
      // This person is the spouse of the anchor (1:1).
      case _LinkKind.wifeOf:
      case _LinkKind.husbandOf:
        await repo.addRelationship(
            familyId: familyId,
            fromMember: anchorIds.first,
            toMember: memberId,
            type: RelType.spouse);
      // This person is a parent of the anchor(s).
      case _LinkKind.fatherOf:
      case _LinkKind.motherOf:
        for (final childId in anchorIds) {
          await repo.addRelationship(
              familyId: familyId,
              fromMember: memberId,
              toMember: childId,
              type: RelType.parent);
        }
      // This person is a child of the anchor(s) — link to both parents if a
      // couple was selected.
      case _LinkKind.sonOf:
      case _LinkKind.daughterOf:
        for (final parentId in anchorIds) {
          await repo.addRelationship(
              familyId: familyId,
              fromMember: parentId,
              toMember: memberId,
              type: RelType.parent);
        }
      // This person is a sibling of the anchor: share the anchor's parents.
      // If the anchor has no parents on record, nothing can be derived — offer
      // to create the shared parent instead of failing silently.
      case _LinkKind.brotherOf:
      case _LinkKind.sisterOf:
        final anchorId = anchorIds.first;
        final linked = await repo.linkSiblingByParents(
            familyId: familyId, newMemberId: memberId, siblingOfId: anchorId);
        if (linked == 0) {
          final created =
              await _promptCreateSharedParent(repo, familyId, memberId, anchorId);
          if (!created) {
            return 'No sibling link added — siblings must share a parent. '
                'Add a parent for them first, then try again.';
          }
        }
      case _LinkKind.none:
        break;
    }
    return null;
  }

  /// Shown when a sibling link can't be derived because the chosen relative has
  /// no parent on record. Offers to create the shared parent and link both as
  /// children. Returns true if the parent was created and linked.
  Future<bool> _promptCreateSharedParent(MemberRepository repo, String familyId,
      String memberId, String anchorId) async {
    final firstCtl = TextEditingController();
    final lastCtl = TextEditingController(text: _lastName.text.trim());
    var pGender = 'female';
    var pLiving = false;
    final anchorName = _anchorLabel ?? 'this person';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add a shared parent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Siblings are linked through a shared parent, but $anchorName '
                  'has no parent on record yet. Add their parent to make them '
                  'siblings.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: firstCtl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Parent first name'),
                ),
                TextField(
                  controller: lastCtl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Last name (optional)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Parent is:'),
                    ChoiceChip(
                      label: const Text('Mother'),
                      selected: pGender == 'female',
                      onSelected: (_) => setLocal(() => pGender = 'female'),
                    ),
                    ChoiceChip(
                      label: const Text('Father'),
                      selected: pGender == 'male',
                      onSelected: (_) => setLocal(() => pGender = 'male'),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Living'),
                  value: pLiving,
                  onChanged: (v) => setLocal(() => pLiving = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add parent & link'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || firstCtl.text.trim().isEmpty) return false;
    await repo.addParentForChildren(
      familyId: familyId,
      firstName: firstCtl.text.trim(),
      lastName: lastCtl.text.trim().isEmpty ? null : lastCtl.text.trim(),
      gender: pGender,
      isLiving: pLiving,
      childIds: [anchorId, memberId],
    );
    return true;
  }

  /// Adds the currently-selected relationship to an existing member (edit flow).
  Future<void> _addRelationshipNow(String familyId) async {
    if (_linkKind == _LinkKind.none || _anchorIds.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final warn = await _applyLink(ref.read(memberRepositoryProvider),
          familyId, widget.memberId!, _linkKind, _anchorIds);
      invalidateFamilyData(ref, familyId);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warn ?? 'Relationship added')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add: $e')));
    }
  }

  Future<void> _removeRelationship(String familyId, String relId) async {
    try {
      await ref.read(memberRepositoryProvider).deleteRelationship(relId);
      invalidateFamilyData(ref, familyId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not remove: $e')));
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

    final existing =
        members.where((m) => m.id == widget.memberId).firstOrNull;
    final myUid = ref.watch(currentSessionProvider)?.user.id;

    // Admins/editors write any member directly. A "relative" can directly edit
    // only their own linked profile (fields + photo, no relationships/delete).
    // Contributors submit suggestions; viewers are read-only.
    final canEdit = family.myRole.canEdit;
    final canSelfEdit = widget.isEditing &&
        family.myRole.isRelative &&
        existing?.linkedUserId != null &&
        existing!.linkedUserId == myUid;
    final canSaveDirect = canEdit || canSelfEdit;
    final canSuggest = family.myRole == FamilyRole.contributor;

    // Hydrate fields once when editing an existing member.
    if (widget.isEditing && !_initialized) {
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
      _anchorLabel = anchorOptions.first.label;
    }

    final title = canSelfEdit
        ? 'Edit my profile'
        : canEdit
            ? (widget.isEditing ? 'Edit member' : 'Add member')
            : (widget.isEditing ? 'Suggest changes' : 'Suggest member');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.isEditing && canEdit)
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
            if (canSuggest) ...[
              _SuggestionBanner(),
              const SizedBox(height: AppSpacing.md),
            ] else if (!canSaveDirect) ...[
              _ViewOnlyBanner(),
              const SizedBox(height: AppSpacing.md),
            ],
            if (canSaveDirect) ...[
              Center(
                child: _PhotoHeader(
                  pickedBytes: _pickedBytes,
                  photoUrl: _photoUrl,
                  onTap: _pickPhoto,
                ),
              ),
              if (widget.isEditing && existing != null)
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AvatarBuilderScreen(member: existing))),
                    icon: const Icon(Icons.face_retouching_natural_rounded, size: 18),
                    label: Text(existing.avatarConfig != null
                        ? 'Edit illustrated avatar'
                        : 'Create illustrated avatar'),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
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
              onChanged: (g) => setState(() {
                _gender = g;
                // Keep the chosen relationship's intent but flip it to match the
                // new gender (e.g. "Son of" -> "Daughter of").
                if (g != null && _linkKind != _LinkKind.none) {
                  _linkKind =
                      _LinkKind.forCategoryGender(_linkKind.category, g == 'male');
                }
              }),
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
              controller: _occupation,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Occupation',
                  prefixIcon: Icon(Icons.work_outline_rounded)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Address',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.home_outlined)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bio,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Bio / notes', alignLabelWithHint: true),
            ),

            // Existing relationships (edit flow): list with remove buttons.
            if (canEdit && widget.isEditing) ...[
              const SizedBox(height: AppSpacing.lg),
              _ExistingRelationships(
                memberId: widget.memberId!,
                members: members,
                relationships: relationships,
                onRemove: (relId) => _removeRelationship(family.id, relId),
              ),
            ],

            // Relationship picker: on add it applies on Save; on edit there's an
            // explicit "Add relationship" button.
            if (canEdit && anchorOptions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _RelationshipPicker(
                kind: _linkKind,
                visibleKinds: _LinkKind.forGender(_gender),
                selectedKey: _anchorKey,
                options: anchorOptions,
                title: widget.isEditing
                    ? 'Add a relationship'
                    : 'How are they related?',
                onKindChanged: (k) => setState(() {
                  _linkKind = k;
                  // Auto-fill gender implied by the relationship.
                  final g = k.impliedGender;
                  if (g != null) _gender = g;
                }),
                onAnchorChanged: (option) => setState(() {
                  _anchorKey = option.key;
                  _anchorIds = option.memberIds;
                  _anchorLabel = option.label;
                }),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _addRelationshipNow(family.id),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Add relationship'),
                ),
              ],
            ],

            if (canSaveDirect || canSuggest) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () => canSaveDirect
                        ? _save(family.id, members)
                        : _submitSuggestion(family.id),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(canSaveDirect
                        ? (canEdit && !widget.isEditing
                            ? 'Add member'
                            : 'Save changes')
                        : 'Send suggestion'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner shown to contributors explaining their edits go through approval.
class _SuggestionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      icon: Icons.info_outline_rounded,
      text: 'Your changes will be sent to a family admin for approval.',
    );
  }
}

/// Banner shown to viewers who can't make changes.
class _ViewOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      icon: Icons.visibility_rounded,
      text: 'You have view-only access to this family.',
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
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
    required this.visibleKinds,
    required this.selectedKey,
    required this.options,
    required this.title,
    required this.onKindChanged,
    required this.onAnchorChanged,
  });

  final _LinkKind kind;
  final List<_LinkKind> visibleKinds;
  final String? selectedKey;
  final List<_AnchorOption> options;
  final String title;
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
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: visibleKinds.map((k) {
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

/// Lists the member's current parents, spouse(s) and children, each removable.
class _ExistingRelationships extends StatelessWidget {
  const _ExistingRelationships({
    required this.memberId,
    required this.members,
    required this.relationships,
    required this.onRemove,
  });

  final String memberId;
  final List<Member> members;
  final List<Relationship> relationships;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {for (final m in members) m.id: m};

    final rows = <Widget>[];
    void addRow(Relationship r, String otherId, String role) {
      final other = byId[otherId];
      if (other == null) return;
      rows.add(_RelationshipRow(
        member: other,
        role: role,
        onRemove: () => onRemove(r.id),
      ));
    }

    for (final r in relationships) {
      if (r.isUnion && (r.fromMember == memberId || r.toMember == memberId)) {
        final other = r.fromMember == memberId ? r.toMember : r.fromMember;
        addRow(r, other, 'Spouse');
      } else if (r.isParentChild && r.toMember == memberId) {
        addRow(r, r.fromMember, 'Parent');
      } else if (r.isParentChild && r.fromMember == memberId) {
        addRow(r, r.toMember, 'Child');
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relationships',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('No relationships yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({
    required this.member,
    required this.role,
    required this.onRemove,
  });

  final Member member;
  final String role;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          MemberAvatar(member: member, radius: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(role,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
