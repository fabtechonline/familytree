import 'package:flutter/material.dart';

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
    final hasPhoto = (member.photoUrl ?? '').isNotEmpty;
    final color = _color;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: hasPhoto ? 0 : 0.18),
      backgroundImage: hasPhoto ? NetworkImage(member.photoUrl!) : null,
      child: hasPhoto
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
