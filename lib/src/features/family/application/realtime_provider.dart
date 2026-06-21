import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../../invite/data/invite_repository.dart';
import '../../members/application/member_providers.dart';
import '../../suggestions/data/suggestion_repository.dart';
import 'family_providers.dart';

/// Subscribes to Realtime changes for a family and invalidates the relevant
/// providers so the dashboard, tree, stats and roster update live when another
/// relative makes a change. Kept alive while a screen watches it; torn down
/// (channel removed) when no longer needed.
final familyRealtimeProvider =
    Provider.autoDispose.family<void, String>((ref, familyId) {
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('family:$familyId');

  void bind(String table, void Function() onChange) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'family_id',
        value: familyId,
      ),
      callback: (_) => onChange(),
    );
  }

  bind('members', () => ref.invalidate(membersProvider(familyId)));
  bind('relationships', () => ref.invalidate(relationshipsProvider(familyId)));
  bind('family_members', () {
    ref.invalidate(rosterProvider(familyId));
    // A role change for the current user should update their permissions live.
    ref.invalidate(myFamiliesProvider);
  });
  bind('edit_suggestions',
      () => ref.invalidate(pendingSuggestionsProvider(familyId)));

  channel.subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});
