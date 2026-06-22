/// A user's role within a family, mirroring the `family_role` enum in Postgres.
enum FamilyRole {
  admin,
  editor,
  contributor,
  relative,
  viewer;

  static FamilyRole fromName(String? value) {
    return FamilyRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => FamilyRole.viewer,
    );
  }

  /// Can add/edit any member and relationships.
  bool get canEdit => this == admin || this == editor;

  /// Can manage roster, invites, billing and settings.
  bool get isAdmin => this == admin;

  /// Can view all but edit only their own linked profile.
  bool get isRelative => this == relative;

  /// Human label.
  String get label => name[0].toUpperCase() + name.substring(1);
}

enum SubscriptionTier {
  free,
  premium;

  static SubscriptionTier fromName(String? value) {
    return SubscriptionTier.values.firstWhere(
      (t) => t.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// A family (the SaaS tenant). [myRole] is the current user's role in this
/// family, populated when loaded through the membership join.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.subscriptionTier,
    required this.createdAt,
    this.settings = const {},
    this.myRole = FamilyRole.viewer,
  });

  final String id;
  final String name;
  final String createdBy;
  final SubscriptionTier subscriptionTier;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
  final FamilyRole myRole;

  /// Opt-in flag for the Point & Recognize face feature.
  bool get faceRecognitionEnabled => settings['face_recognition'] == true;

  factory Family.fromMap(Map<String, dynamic> map, {FamilyRole? role}) {
    return Family(
      id: map['id'] as String,
      name: map['name'] as String,
      createdBy: map['created_by'] as String,
      subscriptionTier:
          SubscriptionTier.fromName(map['subscription_tier'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      settings: (map['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      myRole: role ?? FamilyRole.fromName(map['my_role'] as String?),
    );
  }
}
