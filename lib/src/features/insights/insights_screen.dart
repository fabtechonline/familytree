import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import 'insights.dart';

/// "Family DNA" — playful aggregate facts about the family.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final insights = ref.watch(familyInsightsProvider(family.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Family DNA')),
      body: insights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (s) {
          final cards = <Widget>[
            _Insight('👪', 'People in the tree', '${s.totalPeople}'),
            _Insight('🌳', 'Generations', '${s.generations}'),
            if (s.commonSurname != null)
              _Insight(
                  '🔤',
                  s.commonSurname!.contains('&')
                      ? 'Top surnames (${s.commonSurnameCount} each)'
                      : 'Most common surname (×${s.commonSurnameCount})',
                  s.commonSurname!),
            if (s.commonFirstName != null)
              _Insight(
                  '⭐',
                  s.commonFirstName!.contains('&')
                      ? 'Top first names (${s.commonFirstNameCount} each)'
                      : 'Most common first name (×${s.commonFirstNameCount})',
                  s.commonFirstName!),
            if (s.averageLifespan != null)
              _Insight('🕰️', 'Average lifespan', '${s.averageLifespan} yrs'),
            if (s.oldestLivingName != null)
              _Insight('🎖️', 'Oldest living (with a birth date)',
                  '${s.oldestLivingName} (${s.oldestLivingAge})'),
            _Insight('👥', 'Biggest generation', '${s.largestGeneration} people'),
            if (s.averageChildren != null)
              _Insight('🍼', 'Avg. children per parent',
                  s.averageChildren!.toStringAsFixed(1)),
            _Insight('🗺️', 'Birthplaces', '${s.birthplaceCount}'),
          ];
          return GridView.count(
            crossAxisCount: 2,
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.3,
            children: cards,
          );
        },
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight(this.emoji, this.label, this.value);
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const Spacer(),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
