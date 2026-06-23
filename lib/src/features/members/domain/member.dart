/// A person in the family tree. May or may not be linked to an app user.
class Member {
  const Member({
    required this.id,
    required this.familyId,
    required this.firstName,
    this.lastName,
    this.maidenName,
    this.gender,
    this.birthDate,
    this.deathDate,
    this.isLiving = true,
    this.birthPlace,
    this.bio,
    this.phone,
    this.address,
    this.occupation,
    this.homeLat,
    this.homeLng,
    this.birthLat,
    this.birthLng,
    this.photoUrl,
    this.linkedUserId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String familyId;
  final String firstName;
  final String? lastName;
  final String? maidenName;
  final String? gender;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final bool isLiving;
  final String? birthPlace;
  final String? bio;
  final String? phone;
  final String? address;
  final String? occupation;
  final double? homeLat;
  final double? homeLng;
  final double? birthLat;
  final double? birthLng;
  final String? photoUrl;
  final String? linkedUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => [firstName, lastName].whereType<String>().join(' ');

  /// Two-letter initials for avatar fallbacks.
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = (lastName != null && lastName!.isNotEmpty) ? lastName![0] : '';
    final result = (f + l).toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  int? get birthYear => birthDate?.year;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String?,
      maidenName: map['maiden_name'] as String?,
      gender: map['gender'] as String?,
      birthDate: _parseDate(map['birth_date']),
      deathDate: _parseDate(map['death_date']),
      isLiving: map['is_living'] as bool? ?? true,
      birthPlace: map['birth_place'] as String?,
      bio: map['bio'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      occupation: map['occupation'] as String?,
      homeLat: (map['home_lat'] as num?)?.toDouble(),
      homeLng: (map['home_lng'] as num?)?.toDouble(),
      birthLat: (map['birth_lat'] as num?)?.toDouble(),
      birthLng: (map['birth_lng'] as num?)?.toDouble(),
      photoUrl: map['photo_url'] as String?,
      linkedUserId: map['linked_user_id'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  /// Serializes editable fields for insert/update. Dates are encoded as
  /// `YYYY-MM-DD` to match the Postgres `date` columns.
  Map<String, dynamic> toInsert() {
    String? d(DateTime? value) => value?.toIso8601String().split('T').first;
    return {
      'family_id': familyId,
      'first_name': firstName,
      'last_name': lastName,
      'maiden_name': maidenName,
      'gender': gender,
      'birth_date': d(birthDate),
      'death_date': d(deathDate),
      'is_living': isLiving,
      'birth_place': birthPlace,
      'bio': bio,
      'phone': phone,
      'address': address,
      'occupation': occupation,
      'home_lat': homeLat,
      'home_lng': homeLng,
      'birth_lat': birthLat,
      'birth_lng': birthLng,
      'photo_url': photoUrl,
    };
  }

  Member copyWith({
    String? firstName,
    String? lastName,
    String? maidenName,
    String? gender,
    DateTime? birthDate,
    DateTime? deathDate,
    bool? isLiving,
    String? birthPlace,
    String? bio,
    String? phone,
    String? address,
    String? occupation,
    double? homeLat,
    double? homeLng,
    double? birthLat,
    double? birthLng,
    String? photoUrl,
  }) {
    return Member(
      id: id,
      familyId: familyId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      maidenName: maidenName ?? this.maidenName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      isLiving: isLiving ?? this.isLiving,
      birthPlace: birthPlace ?? this.birthPlace,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      occupation: occupation ?? this.occupation,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      birthLat: birthLat ?? this.birthLat,
      birthLng: birthLng ?? this.birthLng,
      photoUrl: photoUrl ?? this.photoUrl,
      linkedUserId: linkedUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
