import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../members/application/member_providers.dart';
import '../../members/domain/member.dart';
import '../../members/presentation/widgets/member_avatar.dart';
import '../application/tree_providers.dart';
import '../domain/family_graph.dart';
import '../domain/lineage.dart';
import '../domain/tree_layout.dart';

/// Tree view modes available on mobile (Wide/Fan are web-only for now).
enum TreeViewMode { tree, focus }

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
  TreeViewMode _mode = TreeViewMode.tree;
  String? _focusId;
  final Set<String> _collapsed = {};

  Set<String> _descendantsOf(FamilyGraph g, String id) {
    final out = <String>{};
    final stack = [...(g.childrenOf[id] ?? const <String>[])];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      if (!out.add(c)) continue;
      stack.addAll(g.childrenOf[c] ?? const <String>[]);
    }
    return out;
  }

  Set<String> _hourglassOf(FamilyGraph g, String id) {
    final out = <String>{id};
    final up = [...(g.parentsOf[id] ?? const <String>[])];
    while (up.isNotEmpty) {
      final p = up.removeLast();
      if (out.add(p)) up.addAll(g.parentsOf[p] ?? const <String>[]);
    }
    out.addAll(_descendantsOf(g, id));
    for (final m in [...out]) {
      out.addAll(g.spousesOf[m] ?? const <String>[]);
    }
    return out;
  }

  /// The member subset to render given the current mode + collapsed branches.
  List<Member> _visibleMembers(FamilyGraph g) {
    Iterable<Member> base = g.members;
    if (_mode == TreeViewMode.focus && _focusId != null) {
      final set = _hourglassOf(g, _focusId!);
      base = base.where((m) => set.contains(m.id));
    }
    final hidden = <String>{};
    for (final id in _collapsed) {
      hidden.addAll(_descendantsOf(g, id));
    }
    return base.where((m) => !hidden.contains(m.id)).toList();
  }

  Map<String, int> _hiddenCounts(FamilyGraph g, List<Member> visible) {
    final visibleIds = {for (final m in visible) m.id};
    final counts = <String, int>{};
    for (final id in _collapsed) {
      if (!visibleIds.contains(id)) continue;
      final n = _descendantsOf(g, id).length;
      if (n > 0) counts[id] = n;
    }
    return counts;
  }

  void _showNodeMenu(
      Family family, Member member, String? myUid, FamilyGraph graph) {
    final hasChildren = (graph.childrenOf[member.id] ?? const []).isNotEmpty;
    final isCollapsed = _collapsed.contains(member.id);
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
            ListTile(
              leading: const Icon(Icons.center_focus_strong_rounded),
              title: const Text('Focus on this person'),
              subtitle: const Text('Show only ancestors + descendants'),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() {
                  _mode = TreeViewMode.focus;
                  _focusId = member.id;
                });
              },
            ),
            if (hasChildren)
              ListTile(
                leading: Icon(isCollapsed
                    ? Icons.unfold_more_rounded
                    : Icons.unfold_less_rounded),
                title: Text(isCollapsed ? 'Expand branch' : 'Collapse branch'),
                subtitle: const Text('Hide/show this person’s descendants'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    isCollapsed
                        ? _collapsed.remove(member.id)
                        : _collapsed.add(member.id);
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
        data: (fullGraph) {
          final rels =
              ref.watch(relationshipsProvider(family.id)).value ?? const [];
          // Default the focus to "me" (or first member) when entering Focus.
          if (_mode == TreeViewMode.focus &&
              _focusId == null &&
              fullGraph.members.isNotEmpty) {
            final mine = fullGraph.members.firstWhere(
                (m) => m.linkedUserId == myUid,
                orElse: () => fullGraph.members.first);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _focusId == null) {
                setState(() => _focusId = mine.id);
              }
            });
          }

          final visible = _visibleMembers(fullGraph);
          final graph = FamilyGraph.build(visible, rels);
          final layout = TreeLayoutEngine.build(graph);
          final lineage = _lineageOf == null
              ? null
              : computeLineage(graph, _lineageOf!, full: _full);
          final hidden = _hiddenCounts(fullGraph, visible);

          return Stack(
            children: [
              if (layout.isEmpty)
                const _EmptyTree()
              else
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
                              selected: node.member.id == _lineageOf ||
                                  node.member.id == _focusId,
                              highlighted: lineage?.members
                                      .contains(node.member.id) ??
                                  false,
                              dimmed: lineage != null &&
                                  !(lineage.members.contains(node.member.id)),
                              onTap: () => _showNodeMenu(
                                  family, node.member, myUid, fullGraph),
                            ),
                          ),
                        for (final node in layout.nodes)
                          if ((hidden[node.member.id] ?? 0) > 0)
                            Positioned(
                              left: node.center.dx - 18,
                              top: node.center.dy +
                                  layout.nodeSize.height / 2 -
                                  6,
                              child: _CollapseChip(
                                count: hidden[node.member.id]!,
                                onTap: () => setState(
                                    () => _collapsed.remove(node.member.id)),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: AppSpacing.md,
                left: 0,
                right: 0,
                child: Center(
                  child: _ViewSwitcher(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
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
                )
              else if (_mode == TreeViewMode.focus && _focusId != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FocusBar(
                    name: fullGraph.byId[_focusId!]?.firstName ?? 'this person',
                    onClear: () => setState(() {
                      _mode = TreeViewMode.tree;
                      _focusId = null;
                    }),
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

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.mode, required this.onChanged});
  final TreeViewMode mode;
  final ValueChanged<TreeViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget seg(TreeViewMode m, String label, IconData icon) {
      final sel = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16,
                color: sel ? Colors.white : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color:
                        sel ? Colors.white : theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          seg(TreeViewMode.tree, 'Tree', Icons.account_tree_rounded),
          seg(TreeViewMode.focus, 'Focus', Icons.center_focus_strong_rounded),
        ]),
      ),
    );
  }
}

class _FocusBar extends StatelessWidget {
  const _FocusBar({required this.name, required this.onClear});
  final String name;
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
            child: Row(children: [
              const Icon(Icons.center_focus_strong_rounded,
                  color: AppColors.accentSun),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Focused on $name',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Back to full tree',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CollapseChip extends StatelessWidget {
  const _CollapseChip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text('+$count',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
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
