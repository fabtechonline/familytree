/// The kind of edge between two members, mirroring the `rel_type` enum.
///
/// `parent` is directed: [Relationship.fromMember] is the parent of
/// [Relationship.toMember]. `spouse`/`partner` are conceptually undirected.
enum RelType {
  parent,
  spouse,
  partner;

  static RelType fromName(String? value) {
    return RelType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => RelType.parent,
    );
  }
}

enum RelSubtype {
  biological,
  adoptive,
  step,
  foster;

  static RelSubtype fromName(String? value) {
    return RelSubtype.values.firstWhere(
      (t) => t.name == value,
      orElse: () => RelSubtype.biological,
    );
  }
}

class Relationship {
  const Relationship({
    required this.id,
    required this.familyId,
    required this.fromMember,
    required this.toMember,
    required this.type,
    this.subtype = RelSubtype.biological,
  });

  final String id;
  final String familyId;
  final String fromMember;
  final String toMember;
  final RelType type;
  final RelSubtype subtype;

  bool get isParentChild => type == RelType.parent;
  bool get isUnion => type == RelType.spouse || type == RelType.partner;

  factory Relationship.fromMap(Map<String, dynamic> map) {
    return Relationship(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      fromMember: map['from_member'] as String,
      toMember: map['to_member'] as String,
      type: RelType.fromName(map['type'] as String?),
      subtype: RelSubtype.fromName(map['subtype'] as String?),
    );
  }
}
