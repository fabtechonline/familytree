import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../members/domain/member.dart';
import '../../members/presentation/widgets/member_avatar.dart';
import '../application/tree_providers.dart';
import '../domain/tree_layout.dart';

/// The visual family tree: a pan/zoom canvas of member cards connected by
/// parent→child and spouse links.
class FamilyTreeScreen extends ConsumerWidget {
  const FamilyTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final graphAsync = ref.watch(familyGraphProvider(family.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Family tree')),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load tree: $e')),
        data: (graph) {
          final layout = TreeLayoutEngine.build(graph);
          if (layout.isEmpty) {
            return const _EmptyTree();
          }
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(400),
            minScale: 0.2,
            maxScale: 2.5,
            child: SizedBox(
              width: layout.size.width,
              height: layout.size.height,
              child: Stack(
                children: [
                  // Connectors behind the cards.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(
                        layout: layout,
                        scheme: Theme.of(context).colorScheme,
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
                        onTap: () => context.push('/member/${node.member.id}'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.layout, required this.scheme});

  final TreeLayout layout;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final centers = {for (final n in layout.nodes) n.member.id: n.center};
    final halfH = layout.nodeSize.height / 2;
    final halfW = layout.nodeSize.width / 2;

    final parentPaint = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final unionPaint = Paint()
      ..color = AppColors.accentCoral
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Parent→child descents first (behind the union bars).
    for (final d in layout.descents) {
      final a = centers[d.parentA];
      final child = centers[d.child];
      if (a == null || child == null) continue;

      // Anchor: midpoint between the couple, or the single parent.
      final b = d.parentB == null ? null : centers[d.parentB!];
      final anchorX = b == null ? a.dx : (a.dx + b.dx) / 2;
      final anchorY = a.dy + halfH;

      final end = Offset(child.dx, child.dy - halfH);
      final midY = (anchorY + end.dy) / 2;
      final path = Path()
        ..moveTo(anchorX, anchorY)
        ..lineTo(anchorX, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, parentPaint);
    }

    // Spouse links: a bar between the two nodes' inner edges.
    for (final u in layout.unions) {
      final a = centers[u.a];
      final b = centers[u.b];
      if (a == null || b == null) continue;
      final left = a.dx <= b.dx ? a : b;
      final right = a.dx <= b.dx ? b : a;
      // If they're side-by-side on the same row, connect inner edges; otherwise
      // just connect centers.
      if ((left.dy - right.dy).abs() < 1) {
        canvas.drawLine(
          Offset(left.dx + halfW, left.dy),
          Offset(right.dx - halfW, right.dy),
          unionPaint,
        );
      } else {
        canvas.drawLine(a, b, unionPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.layout != layout;
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({required this.member, required this.onTap});
  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = _years(member);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MemberAvatar(member: member, radius: 30),
              const SizedBox(height: 6),
              Text(
                member.fullName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
              ),
              if (years != null) ...[
                const SizedBox(height: 2),
                Text(years,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
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
