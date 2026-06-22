import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../members/domain/member.dart';
import '../members/presentation/widgets/member_avatar.dart';
import '../tree/application/tree_providers.dart';

/// Time Machine — scrub through the years and watch the family grow.
class TimeMachineScreen extends ConsumerStatefulWidget {
  const TimeMachineScreen({super.key});

  @override
  ConsumerState<TimeMachineScreen> createState() => _TimeMachineScreenState();
}

class _TimeMachineScreenState extends ConsumerState<TimeMachineScreen> {
  int? _year;
  Timer? _timer;
  bool _playing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay(int minYear, int maxYear) {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _playing = true;
      if ((_year ?? maxYear) >= maxYear) _year = minYear;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      final current = _year ?? minYear;
      if (current >= maxYear) {
        t.cancel();
        setState(() => _playing = false);
        return;
      }
      setState(() => _year = current + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final graphAsync = ref.watch(familyGraphProvider(family.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Time Machine')),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (graph) {
          final dated =
              graph.members.where((m) => m.birthYear != null).toList();
          if (dated.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'Add birth years to members to travel through time.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final minYear =
              dated.map((m) => m.birthYear!).reduce((a, b) => a < b ? a : b);
          final maxYear = DateTime.now().year;
          final year = (_year ?? maxYear).clamp(minYear, maxYear);

          final bornBy = dated.where((m) => m.birthYear! <= year).toList()
            ..sort((a, b) => a.birthYear!.compareTo(b.birthYear!));
          final aliveThen = bornBy.where((m) {
            final d = m.deathDate?.year;
            return m.isLiving || d == null || d > year;
          }).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Column(
                  children: [
                    Text('$year',
                        style: theme.textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                        '${bornBy.length} born by this year · $aliveThen alive',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _togglePlay(minYear, maxYear),
                          icon: Icon(
                              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            min: minYear.toDouble(),
                            max: maxYear.toDouble(),
                            value: year.toDouble(),
                            label: '$year',
                            divisions: (maxYear - minYear).clamp(1, 1000),
                            onChanged: (v) => setState(() {
                              _year = v.round();
                              _playing = false;
                              _timer?.cancel();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: bornBy.isEmpty
                    ? Center(
                        child: Text('No one born yet by $year',
                            style: theme.textTheme.bodyMedium))
                    : GridView.count(
                        crossAxisCount: 4,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          for (final m in bornBy.reversed)
                            _PersonChip(member: m, justBorn: m.birthYear == year),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.member, required this.justBorn});
  final Member member;
  final bool justBorn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            MemberAvatar(member: member, radius: 26),
            if (justBorn)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary, shape: BoxShape.circle),
                  child: const Text('✨', style: TextStyle(fontSize: 10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(member.firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall),
        Text('${member.birthYear}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
