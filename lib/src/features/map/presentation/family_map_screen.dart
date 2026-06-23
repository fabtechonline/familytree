import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../members/application/member_providers.dart';
import '../../members/domain/member.dart';
import '../../members/domain/relationship.dart';
import '../../members/presentation/widgets/member_avatar.dart';

const _parentColor = AppColors.seed; // teal
const _spouseColor = AppColors.accentCoral;
const _migrationColor = AppColors.accentSun;

/// Spread markers sharing the same coordinate into a small ring so each is
/// individually visible/tappable (e.g. several relatives born in one town).
Map<String, LatLng> _spread(List<({String id, double lat, double lng})> pts) {
  final groups = <String, List<({String id, double lat, double lng})>>{};
  for (final p in pts) {
    final k = '${p.lat.toStringAsFixed(4)},${p.lng.toStringAsFixed(4)}';
    (groups[k] ??= []).add(p);
  }
  final out = <String, LatLng>{};
  for (final grp in groups.values) {
    if (grp.length == 1) {
      out[grp.first.id] = LatLng(grp.first.lat, grp.first.lng);
      continue;
    }
    const r = 0.02;
    for (var i = 0; i < grp.length; i++) {
      final a = (i / grp.length) * 2 * math.pi;
      out[grp[i].id] = LatLng(grp[i].lat + r * math.sin(a), grp[i].lng + r * math.cos(a));
    }
  }
  return out;
}

class FamilyMapScreen extends ConsumerStatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  ConsumerState<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends ConsumerState<FamilyMapScreen> {
  final MapController _mapController = MapController();
  bool _homes = true;
  bool _birth = true;
  bool _migration = true;
  bool _web = true;

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom + delta).clamp(1.0, 18.0));
  }

  void _showMember(Member m, String? place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemberAvatar(member: m, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.fullName,
                            style: Theme.of(sheetCtx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (place != null)
                          Text(place,
                              style: Theme.of(sheetCtx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.push('/profile/${m.id}');
                },
                icon: const Icon(Icons.person_rounded),
                label: const Text('View profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _avatarMarker(Member m, LatLng pos, Color ring, String? place) {
    return Marker(
      point: pos,
      width: 46,
      height: 46,
      child: GestureDetector(
        onTap: () => _showMember(m, place),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ring,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: MemberAvatar(member: m, radius: 19),
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
    final members = ref.watch(membersProvider(family.id)).value ?? const <Member>[];
    final rels =
        ref.watch(relationshipsProvider(family.id)).value ?? const <Relationship>[];

    final homePos = _spread([
      for (final m in members)
        if (m.homeLat != null && m.homeLng != null)
          (id: m.id, lat: m.homeLat!, lng: m.homeLng!),
    ]);
    final birthPos = _spread([
      for (final m in members)
        if (m.birthLat != null && m.birthLng != null)
          (id: m.id, lat: m.birthLat!, lng: m.birthLng!),
    ]);
    final byId = {for (final m in members) m.id: m};
    LatLng? primary(String id) => homePos[id] ?? birthPos[id];

    final allPoints = <LatLng>[...homePos.values, ...birthPos.values];

    // Family web edges between primary positions of related members.
    final webLines = <Polyline>[];
    for (final r in rels) {
      final a = primary(r.fromMember);
      final b = primary(r.toMember);
      if (a == null || b == null) continue;
      webLines.add(Polyline(
        points: [a, b],
        strokeWidth: 2,
        color: (r.isUnion ? _spouseColor : _parentColor).withValues(alpha: 0.5),
      ));
    }
    // Migration arcs (birth → home).
    final migrationLines = <Polyline>[];
    for (final m in members) {
      final h = homePos[m.id];
      final bp = birthPos[m.id];
      if (h != null && bp != null) {
        migrationLines.add(Polyline(
          points: [bp, h],
          strokeWidth: 2,
          color: _migrationColor,
          pattern: StrokePattern.dashed(segments: const [6, 6]),
        ));
      }
    }

    final mapped = members.where((m) => primary(m.id) != null).length;
    final needLoc = members.where((m) => primary(m.id) == null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family map'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              _chip('Homes', _homes, _parentColor, (v) => setState(() => _homes = v)),
              _chip('Birthplaces', _birth, _migrationColor, (v) => setState(() => _birth = v)),
              _chip('Migration', _migration, _migrationColor, (v) => setState(() => _migration = v)),
              _chip('Family web', _web, _spouseColor, (v) => setState(() => _web = v)),
            ]),
          ),
        ),
      ),
      body: allPoints.isEmpty
          ? const _EmptyMap()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$mapped mapped${needLoc > 0 ? ' · $needLoc need a location' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(children: [
                    FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: allPoints.first,
                      initialZoom: 4,
                      initialCameraFit: allPoints.length > 1
                          ? CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(allPoints),
                              padding: const EdgeInsets.all(56),
                            )
                          : null,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'za.co.riza.app',
                      ),
                      if (_web) PolylineLayer(polylines: webLines),
                      if (_migration) PolylineLayer(polylines: migrationLines),
                      if (_homes)
                        MarkerLayer(markers: [
                          for (final e in homePos.entries)
                            _avatarMarker(byId[e.key]!, e.value, _parentColor,
                                byId[e.key]!.address),
                        ]),
                      if (_birth)
                        MarkerLayer(markers: [
                          for (final e in birthPos.entries)
                            _avatarMarker(byId[e.key]!, e.value, _migrationColor,
                                'Born in ${byId[e.key]!.birthPlace ?? ''}'),
                        ]),
                      const RichAttributionWidget(attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ]),
                    ],
                  ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _zoomButton(Icons.add_rounded, () => _zoomBy(1)),
                          const SizedBox(height: 8),
                          _zoomButton(Icons.remove_rounded, () => _zoomBy(-1)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.seed),
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, Color color, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: on,
        avatar: CircleAvatar(backgroundColor: on ? color : Colors.grey, radius: 6),
        onSelected: onChanged,
      ),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, size: 48, color: AppColors.seed),
            const SizedBox(height: 12),
            Text('No locations yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add an address or birthplace to your members and they’ll appear on the map.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
