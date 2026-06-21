/// A proposed change submitted by a contributor, awaiting admin review.
class EditSuggestion {
  const EditSuggestion({
    required this.id,
    required this.familyId,
    required this.suggestedBy,
    required this.kind,
    this.targetMemberId,
    required this.payload,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String suggestedBy;
  final String kind; // 'add_member' | 'edit_member'
  final String? targetMemberId;
  final Map<String, dynamic> payload;
  final String? note;
  final DateTime createdAt;

  bool get isAdd => kind == 'add_member';

  /// Human-readable name of the proposed/edited person.
  String get proposedName {
    final first = (payload['first_name'] ?? '').toString().trim();
    final last = (payload['last_name'] ?? '').toString().trim();
    return [first, last].where((s) => s.isNotEmpty).join(' ');
  }

  factory EditSuggestion.fromMap(Map<String, dynamic> map) {
    return EditSuggestion(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      suggestedBy: map['suggested_by'] as String,
      kind: map['kind'] as String,
      targetMemberId: map['target_member_id'] as String?,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
