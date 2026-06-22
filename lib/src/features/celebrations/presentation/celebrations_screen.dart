import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../announcements/data/announcement_repository.dart';
import '../../family/application/family_providers.dart';
import '../celebrations.dart';

/// Full list of upcoming birthdays and anniversaries, with one-tap greetings.
class CelebrationsScreen extends ConsumerWidget {
  const CelebrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final celebrations = ref.watch(upcomingCelebrationsProvider(family.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming celebrations')),
      body: celebrations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (items) {
          if (items.isEmpty) return const _EmptyCelebrations();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => CelebrationTile(
              celebration: items[i],
              onGreet: family.myRole.name == 'viewer'
                  ? null
                  : () => _greet(context, ref, family.id, items[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _greet(BuildContext context, WidgetRef ref, String familyId,
      Celebration c) async {
    final isBirthday = c.kind == CelebrationKind.birthday;
    final title = isBirthday
        ? 'Happy Birthday, ${c.title}! 🎂'
        : 'Happy Anniversary, ${c.title}! 💍';
    await ref.read(announcementRepositoryProvider).post(
          familyId: familyId,
          type: isBirthday ? 'birthday' : 'wedding',
          title: title,
          body: isBirthday && c.years > 0 ? 'Turning ${c.years} today!' : null,
        );
    ref.invalidate(announcementsProvider(familyId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Greeting posted to the family feed 🎉')));
  }
}

/// Reusable tile for a celebration (used on the screen and dashboard card).
class CelebrationTile extends StatelessWidget {
  const CelebrationTile({super.key, required this.celebration, this.onGreet});

  final Celebration celebration;
  final VoidCallback? onGreet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = celebration;
    final isBirthday = c.kind == CelebrationKind.birthday;
    final emoji = isBirthday ? '🎂' : '💍';
    final when = c.isToday
        ? 'Today!'
        : c.daysUntil == 1
            ? 'Tomorrow'
            : 'in ${c.daysUntil} days';
    final detail = isBirthday
        ? (c.years > 0 ? 'Turning ${c.years} · $when' : when)
        : (c.years > 0 ? '${c.years} years · $when' : when);

    return Card(
      color: c.isToday ? theme.colorScheme.primary.withValues(alpha: 0.10) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: onGreet == null
            ? null
            : TextButton.icon(
                onPressed: onGreet,
                icon: const Icon(Icons.celebration_rounded, size: 18),
                label: const Text('Greet'),
              ),
      ),
    );
  }
}

class _EmptyCelebrations extends StatelessWidget {
  const _EmptyCelebrations();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('No upcoming celebrations',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add birth dates to members (and marriage dates to couples) to see birthdays and anniversaries here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
