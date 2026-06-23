import 'package:flutter/material.dart';

import '../../../avatars/dicebear.dart';
import '../../domain/member.dart';

/// Circular avatar for a member: their photo if available, otherwise colorful
/// initials. The color is derived from the name so each person is visually
/// consistent across the app.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.radius = 24});

  final Member member;
  final double radius;

  static const _palette = [
    Color(0xFF1FB6A6),
    Color(0xFFFF7E6B),
    Color(0xFF4D9DE0),
    Color(0xFFFFC857),
    Color(0xFF9B7EDE),
    Color(0xFF5BBF7B),
  ];

  Color get _color {
    final key = member.fullName.isEmpty ? member.id : member.fullName;
    return _palette[key.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    // Priority: illustrated avatar (deliberate choice) → real photo → initials.
    ImageProvider? image;
    if (member.avatarConfig != null) {
      image = NetworkImage(dicebearUrl(member.avatarConfig!, size: (radius * 4).round()));
    } else if ((member.photoUrl ?? '').isNotEmpty) {
      image = NetworkImage(member.photoUrl!);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: image == null ? 0.18 : 0),
      backgroundImage: image,
      child: image != null
          ? null
          : Text(
              member.initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.72,
              ),
            ),
    );
  }
}
