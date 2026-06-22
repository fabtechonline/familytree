import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../invite/data/invite_repository.dart';
import '../data/announcement_repository.dart';
import '../domain/announcement.dart';

/// The private family feed: births, weddings, news, birthday greetings.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final feed = ref.watch(announcementsProvider(family.id));
    final roster = ref.watch(rosterProvider(family.id)).value ?? const [];
    final myId = ref.watch(currentSessionProvider)?.user.id;
    final canPost = family.myRole != FamilyRole.viewer;
    String authorName(String uid) =>
        roster.where((m) => m.userId == uid).map((m) => m.label).firstOrNull ??
        'A family member';

    return Scaffold(
      appBar: AppBar(title: const Text('Family feed')),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => _compose(context, ref, family.id),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Post'),
            )
          : null,
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load feed: $e')),
        data: (items) {
          if (items.isEmpty) return const _EmptyFeed();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, 96 + MediaQuery.paddingOf(context).bottom),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final a = items[i];
              final canDelete = a.authorId == myId || family.myRole.isAdmin;
              return _AnnouncementCard(
                announcement: a,
                author: authorName(a.authorId),
                onDelete: canDelete
                    ? () async {
                        await ref
                            .read(announcementRepositoryProvider)
                            .delete(a.id);
                        ref.invalidate(announcementsProvider(family.id));
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _compose(
      BuildContext context, WidgetRef ref, String familyId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ComposeSheet(familyId: familyId),
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = 'news';
  bool _posting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(announcementRepositoryProvider).post(
            familyId: widget.familyId,
            type: _type,
            title: _title.text.trim(),
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
          );
      ref.invalidate(announcementsProvider(widget.familyId));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: AnnouncementType.all.map((t) {
              return ChoiceChip(
                label: Text('${t.emoji} ${t.label}'),
                selected: _type == t.key,
                onSelected: (_) => setState(() => _type = t.key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _body,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Say something (optional)',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _posting ? null : _post,
            child: _posting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Post to family'),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.author,
    required this.onDelete,
  });

  final Announcement announcement;
  final String author;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AnnouncementType.of(announcement.type);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(t.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(announcement.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('$author · ${_ago(announcement.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if ((announcement.body ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(announcement.body!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('No posts yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Share family news, births, weddings and more.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
