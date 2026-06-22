import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../members/domain/member.dart';
import '../../members/presentation/widgets/member_avatar.dart';
import '../application/tree_providers.dart';
import '../domain/lineage.dart';
import '../domain/tree_layout.dart';

/// The visual family tree: a pan/zoom canvas of member cards connected by
/// parent→child and spouse links. Tapping a node opens an action menu, and
/// "View lineage" highlights that person's family paths.
class FamilyTreeScreen extends ConsumerStatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  ConsumerState<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends ConsumerState<FamilyTreeScreen> {
  String? _lineageOf;
  bool _full = false;

  void _showNodeMenu(Family family, Member member, String? myUid) {
    final canEditThis = family.myRole.canEdit ||
        (family.myRole.isRelative &&
            myUid != null &&
            member.linkedUserId == myUid);
    final canSuggestThis = family.myRole == FamilyRole.contributor;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  MemberAvatar(member: member, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(member.fullName,
                        style: Theme.of(sheetCtx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('View profile'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/profile/${member.id}');
              },
            ),
            if (canEditThis)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(family.myRole.isRelative ? 'Edit my profile' : 'Edit'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/member/${member.id}');
                },
              )
            else if (canSuggestThis)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Suggest an edit'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/member/${member.id}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.hub_rounded),
              title: const Text('View lineage'),
              subtitle: const Text('Highlight parents, spouse, children…'),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() {
                  _lineageOf = member.id;
                  _full = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final graphAsync = ref.watch(familyGraphProvider(family.id));
    final myUid = ref.watch(currentSessionProvider)?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Family tree')),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load tree: $e')),
        data: (graph) {
          final layout = TreeLayoutEngine.build(graph);
          if (layout.isEmpty) return const _EmptyTree();

          final lineage = _lineageOf == null
              ? null
              : computeLineage(graph, _lineageOf!, full: _full);

          return Stack(
            children: [
              InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 2.5,
                child: SizedBox(
                  width: layout.size.width,
                  height: layout.size.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgePainter(
                            layout: layout,
                            scheme: Theme.of(context).colorScheme,
                            lineage: lineage,
                          ),
                        ),
                      ),
                      for (final node in layout.nodes)
                        Positioned(
                          left: node.center.dx - layout.nodeSize.width / 2,
                          top: node.center.dy - layout.nodeSize.height / 2,
                          width: layout.nodeSize.width,
                          height: layout.nodeSize.height,
                          child: _TreeNodeCard(
                            member: node.member,
                            badge: lineage?.labelFor(node.member.id),
                            selected: node.member.id == _lineageOf,
                            highlighted:
                                lineage?.members.contains(node.member.id) ?? false,
                            dimmed: lineage != null &&
                                !(lineage.members.contains(node.member.id)),
                            onTap: () =>
                                _showNodeMenu(family, node.member, myUid),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (lineage != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _LineageBar(
                    name: graph.byId[_lineageOf!]?.firstName ?? 'this person',
                    full: _full,
                    onToggleFull: () => setState(() => _full = !_full),
                    onClear: () => setState(() => _lineageOf = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.layout, required this.scheme, this.lineage});

  final TreeLayout layout;
  final ColorScheme scheme;
  final Lineage? lineage;

  bool _descentHighlighted(DescentLink d) {
    final l = lineage;
    if (l == null) return false;
    return l.descentChildIds.contains(d.child) ||
        l.descentParentIds.contains(d.parentA) ||
        (d.parentB != null && l.descentParentIds.contains(d.parentB));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centers = {for (final n in layout.nodes) n.member.id: n.center};
    final halfH = layout.nodeSize.height / 2;
    final halfW = layout.nodeSize.width / 2;
    final active = lineage != null;

    final parentPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: active ? 0.35 : 1)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final unionPaint = Paint()
      ..color = AppColors.accentCoral.withValues(alpha: active ? 0.35 : 1)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final highlightPaint = Paint()
      ..color = AppColors.accentSun
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Parent→child "bus" per parent anchor.
    final groups = <String, List<DescentLink>>{};
    for (final d in layout.descents) {
      groups.putIfAbsent('${d.parentA}|${d.parentB}', () => []).add(d);
    }

    for (final group in groups.values) {
      final first = group.first;
      final a = centers[first.parentA];
      if (a == null) continue;
      final b = first.parentB == null ? null : centers[first.parentB!];
      final anchorX = b == null ? a.dx : (a.dx + b.dx) / 2;
      final anchorY = a.dy + halfH;

      final groupHi = group.any(_descentHighlighted);
      final trunkPaint = groupHi ? highlightPaint : parentPaint;

      final childTops = <Offset>[];
      final hiTops = <Offset>[];
      for (final d in group) {
        final c = centers[d.child];
        if (c == null) continue;
        final top = Offset(c.dx, c.dy - halfH);
        childTops.add(top);
        if (groupHi && _descentHighlighted(d)) hiTops.add(top);
      }
      if (childTops.isEmpty) continue;

      final busY = anchorY + (childTops.first.dy - anchorY) / 2;
      canvas.drawLine(Offset(anchorX, anchorY), Offset(anchorX, busY), trunkPaint);

      final xs = [anchorX, ...childTops.map((o) => o.dx)];
      final barLeft = xs.reduce((v, e) => e < v ? e : v);
      final barRight = xs.reduce((v, e) => e > v ? e : v);
      if (barRight - barLeft > 0.5) {
        canvas.drawLine(Offset(barLeft, busY), Offset(barRight, busY), trunkPaint);
      }
      for (final top in childTops) {
        final dropHi = groupHi && hiTops.contains(top);
        canvas.drawLine(
            Offset(top.dx, busY), top, dropHi ? highlightPaint : parentPaint);
      }
    }

    // Spouse links + heart.
    for (final u in layout.unions) {
      final a = centers[u.a];
      final b = centers[u.b];
      if (a == null || b == null) continue;
      final hi = lineage != null &&
          (lineage!.unionMembers.contains(u.a) ||
              lineage!.unionMembers.contains(u.b));
      final left = a.dx <= b.dx ? a : b;
      final right = a.dx <= b.dx ? b : a;
      final sameRow = (left.dy - right.dy).abs() < 1;
      final start = sameRow ? Offset(left.dx + halfW, left.dy) : left;
      final end = sameRow ? Offset(right.dx - halfW, right.dy) : right;
      canvas.drawLine(start, end, hi ? highlightPaint : unionPaint);
      _drawHeart(canvas,
          Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2), active && !hi);
    }
  }

  void _drawHeart(Canvas canvas, Offset c, bool dim) {
    const r = 11.0;
    final color = AppColors.accentCoral.withValues(alpha: dim ? 0.4 : 1);
    canvas.drawCircle(c, r, Paint()..color = scheme.surface);
    canvas.drawCircle(
        c, r, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.favorite_rounded.codePoint),
        style: TextStyle(
          fontSize: 14,
          fontFamily: Icons.favorite_rounded.fontFamily,
          package: Icons.favorite_rounded.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.lineage != lineage;
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.member,
    required this.onTap,
    this.badge,
    this.selected = false,
    this.highlighted = false,
    this.dimmed = false,
  });

  final Member member;
  final VoidCallback onTap;
  final String? badge;
  final bool selected;
  final bool highlighted;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = _years(member);
    final ringColor = selected ? theme.colorScheme.primary : AppColors.accentSun;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: highlighted
              ? BorderSide(color: ringColor, width: selected ? 3 : 2)
              : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentSun.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A6D00))),
                  ),
                MemberAvatar(member: member, radius: badge != null ? 24 : 30),
                const SizedBox(height: 6),
                Text(
                  member.fullName,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
                if (years != null && badge == null) ...[
                  const SizedBox(height: 2),
                  Text(years,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _years(Member m) {
    if (m.birthYear == null && m.deathDate == null) return null;
    final birth = m.birthYear?.toString() ?? '?';
    if (!m.isLiving || m.deathDate != null) {
      final death = m.deathDate?.year.toString() ?? '';
      return '$birth – $death';
    }
    return 'b. $birth';
  }
}

class _LineageBar extends StatelessWidget {
  const _LineageBar({
    required this.name,
    required this.full,
    required this.onToggleFull,
    required this.onClear,
  });

  final String name;
  final bool full;
  final VoidCallback onToggleFull;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Card(
          color: theme.colorScheme.surface,
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded, color: AppColors.accentSun),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("$name's ${full ? 'full line' : 'family'}",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: onToggleFull,
                  child: Text(full ? 'Immediate' : 'Full line'),
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Your tree is empty',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Add members and link them to see your tree grow here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
