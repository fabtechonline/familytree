import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../invite/data/invite_repository.dart';
import '../../members/application/member_providers.dart';
import '../data/suggestion_repository.dart';
import '../domain/edit_suggestion.dart';

/// Admin queue of contributor suggestions to approve or reject.
class SuggestionsScreen extends ConsumerWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = ref.watch(pendingSuggestionsProvider(family.id));
    final roster = ref.watch(rosterProvider(family.id)).value ?? const [];
    String suggester(String uid) =>
        roster.where((m) => m.userId == uid).map((m) => m.label).firstOrNull ??
        'A contributor';

    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load suggestions: $e')),
        data: (items) {
          if (items.isEmpty) return const _EmptyQueue();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _SuggestionCard(
              suggestion: items[i],
              suggestedBy: suggester(items[i].suggestedBy),
              onApprove: () async {
                await ref
                    .read(suggestionRepositoryProvider)
                    .approve(items[i].id);
                ref.invalidate(pendingSuggestionsProvider(family.id));
                invalidateFamilyData(ref, family.id);
              },
              onReject: () async {
                await ref.read(suggestionRepositoryProvider).reject(items[i].id);
                ref.invalidate(pendingSuggestionsProvider(family.id));
              },
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.suggestedBy,
    required this.onApprove,
    required this.onReject,
  });

  final EditSuggestion suggestion;
  final String suggestedBy;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _summaryFields(suggestion.payload);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(suggestion.isAdd ? 'Add member' : 'Edit member'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                const Spacer(),
                Text('by $suggestedBy',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              suggestion.proposedName.isEmpty
                  ? '(no name)'
                  : suggestion.proposedName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(fields,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
            if ((suggestion.note ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('“${suggestion.note}”',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _summaryFields(Map<String, dynamic> p) {
    final parts = <String>[];
    final gender = (p['gender'] ?? '').toString();
    if (gender.isNotEmpty) parts.add(gender);
    final birth = (p['birth_date'] ?? '').toString();
    if (birth.isNotEmpty) parts.add('b. ${birth.split('-').first}');
    final place = (p['birth_place'] ?? '').toString();
    if (place.isNotEmpty) parts.add(place);
    if (p['is_living'] == false) parts.add('deceased');
    return parts.join(' · ');
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('No suggestions to review',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Contributor suggestions will appear here.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
