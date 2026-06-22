/// A post in the private family feed.
class Announcement {
  const Announcement({
    required this.id,
    required this.familyId,
    required this.authorId,
    required this.type,
    required this.title,
    this.body,
    this.mediaUrl,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String authorId;
  final String type; // 'news' | 'birth' | 'wedding' | 'graduation' | 'memorial' | 'birthday'
  final String title;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      authorId: map['author_id'] as String,
      type: map['type'] as String? ?? 'news',
      title: map['title'] as String,
      body: map['body'] as String?,
      mediaUrl: map['media_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Display metadata for an announcement type.
class AnnouncementType {
  const AnnouncementType(this.key, this.label, this.emoji);
  final String key;
  final String label;
  final String emoji;

  static const all = [
    AnnouncementType('news', 'News', '📣'),
    AnnouncementType('birthday', 'Birthday', '🎂'),
    AnnouncementType('birth', 'New baby', '👶'),
    AnnouncementType('wedding', 'Wedding', '💍'),
    AnnouncementType('graduation', 'Graduation', '🎓'),
    AnnouncementType('memorial', 'In memoriam', '🕊️'),
  ];

  static AnnouncementType of(String key) =>
      all.firstWhere((t) => t.key == key, orElse: () => all.first);
}
