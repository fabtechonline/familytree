import '../../family/domain/family.dart';

/// An invite code for joining a family.
class Invitation {
  const Invitation({
    required this.id,
    required this.familyId,
    required this.code,
    required this.role,
    this.expiresAt,
  });

  final String id;
  final String familyId;
  final String code;
  final FamilyRole role;
  final DateTime? expiresAt;

  factory Invitation.fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      code: map['code'] as String,
      role: FamilyRole.fromName(map['role'] as String?),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.tryParse(map['expires_at'] as String),
    );
  }
}

/// A read-only preview of an invite, shown before the user commits to joining.
class InvitePreview {
  const InvitePreview({
    required this.familyId,
    required this.familyName,
    required this.role,
    required this.valid,
  });

  final String familyId;
  final String familyName;
  final FamilyRole role;
  final bool valid;

  factory InvitePreview.fromMap(Map<String, dynamic> map) {
    return InvitePreview(
      familyId: map['family_id'] as String,
      familyName: map['family_name'] as String,
      role: FamilyRole.fromName(map['role'] as String?),
      valid: map['valid'] as bool? ?? false,
    );
  }
}

/// A member of a family with their display info and role, for the roster.
class RosterMember {
  const RosterMember({
    required this.userId,
    required this.role,
    this.displayName,
    this.email,
    required this.joinedAt,
  });

  final String userId;
  final FamilyRole role;
  final String? displayName;
  final String? email;
  final DateTime joinedAt;

  String get label {
    if ((displayName ?? '').trim().isNotEmpty) return displayName!.trim();
    if ((email ?? '').trim().isNotEmpty) return email!.trim();
    return 'Member';
  }

  String get initials {
    final source = label;
    final parts = source.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  factory RosterMember.fromMap(Map<String, dynamic> map) {
    return RosterMember(
      userId: map['user_id'] as String,
      role: FamilyRole.fromName(map['role'] as String?),
      displayName: map['display_name'] as String?,
      email: map['email'] as String?,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }
}
