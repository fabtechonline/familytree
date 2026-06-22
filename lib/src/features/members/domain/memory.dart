/// A photo memory attached to a member.
class Memory {
  const Memory({
    required this.id,
    required this.memberId,
    required this.mediaUrl,
    this.caption,
    this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String memberId;
  final String mediaUrl;
  final String? caption;
  final String? uploadedBy;
  final DateTime createdAt;

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      mediaUrl: map['media_url'] as String,
      caption: map['caption'] as String?,
      uploadedBy: map['uploaded_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
