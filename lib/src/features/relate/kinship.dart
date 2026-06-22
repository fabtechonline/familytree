import '../tree/domain/family_graph.dart';

/// The computed relationship of personB relative to personA.
class Kinship {
  const Kinship({required this.label, required this.related});
  final String label;
  final bool related;
}

/// Ancestors of [id] (including self at distance 0), mapped to generation
/// distance upward via parent edges.
Map<String, int> _ancestors(FamilyGraph g, String id) {
  final result = <String, int>{id: 0};
  final queue = <String>[id];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    final d = result[cur]!;
    for (final p in g.parentsOf[cur] ?? const <String>[]) {
      if (!result.containsKey(p)) {
        result[p] = d + 1;
        queue.add(p);
      }
    }
  }
  return result;
}

String? _genderOf(FamilyGraph g, String id) => g.byId[id]?.gender;

String _greats(int n) => 'great-' * n;

/// Ancestor term: distance 1 = parent, 2 = grandparent, 3+ = great-…-grandparent.
String _ancestorTerm(int up, String? gender) {
  final base = gender == 'male'
      ? ['father', 'grandfather']
      : gender == 'female'
          ? ['mother', 'grandmother']
          : ['parent', 'grandparent'];
  if (up == 1) return base[0];
  if (up == 2) return base[1];
  return '${_greats(up - 2)}${base[1]}';
}

String _descendantTerm(int down, String? gender) {
  final base = gender == 'male'
      ? ['son', 'grandson']
      : gender == 'female'
          ? ['daughter', 'granddaughter']
          : ['child', 'grandchild'];
  if (down == 1) return base[0];
  if (down == 2) return base[1];
  return '${_greats(down - 2)}${base[1]}';
}

String _siblingTerm(String? gender) => gender == 'male'
    ? 'brother'
    : gender == 'female'
        ? 'sister'
        : 'sibling';

String _auntUncleTerm(int up, String? gender) {
  final base = gender == 'male'
      ? 'uncle'
      : gender == 'female'
          ? 'aunt'
          : 'aunt/uncle';
  // up==2 -> aunt/uncle, up==3 -> great-aunt/uncle, ...
  return up == 2 ? base : '${_greats(up - 2)}$base';
}

String _nieceNephewTerm(int down, String? gender) {
  final base = gender == 'male'
      ? 'nephew'
      : gender == 'female'
          ? 'niece'
          : 'niece/nephew';
  return down == 2 ? base : '${_greats(down - 2)}$base';
}

String _ordinal(int n) {
  switch (n) {
    case 1:
      return 'first';
    case 2:
      return 'second';
    case 3:
      return 'third';
    case 4:
      return 'fourth';
    case 5:
      return 'fifth';
    default:
      return '${n}th';
  }
}

String _removed(int n) {
  if (n == 0) return '';
  if (n == 1) return ' once removed';
  if (n == 2) return ' twice removed';
  if (n == 3) return ' thrice removed';
  return ' $n times removed';
}

/// Translates an (up, down) distance pair from the lowest common ancestor into
/// a kinship term, from A's perspective describing B (whose gender is [genderB]).
String _labelFor(int up, int down, String? genderB) {
  if (up == 0) return _descendantTerm(down, genderB); // B descends from A
  if (down == 0) return _ancestorTerm(up, genderB); // B is A's ancestor
  if (up == 1 && down == 1) return _siblingTerm(genderB);
  if (down == 1) return _auntUncleTerm(up, genderB); // B is up the side
  if (up == 1) return _nieceNephewTerm(down, genderB); // B is down the side
  final degree = (up < down ? up : down) - 1;
  return '${_ordinal(degree)} cousin${_removed((up - down).abs())}';
}

/// Computes how [bId] is related to [aId].
Kinship computeKinship(FamilyGraph g, String aId, String bId) {
  if (aId == bId) return const Kinship(label: 'the same person', related: true);

  // Direct spouse / partner.
  if ((g.spousesOf[aId] ?? const []).contains(bId)) {
    final gb = _genderOf(g, bId);
    final term = gb == 'male'
        ? 'husband'
        : gb == 'female'
            ? 'wife'
            : 'spouse';
    return Kinship(label: term, related: true);
  }

  final ancA = _ancestors(g, aId);
  final ancB = _ancestors(g, bId);

  String? lca;
  int best = 1 << 30;
  for (final entry in ancA.entries) {
    final db = ancB[entry.key];
    if (db != null && entry.value + db < best) {
      best = entry.value + db;
      lca = entry.key;
    }
  }

  if (lca != null) {
    return Kinship(
      label: _labelFor(ancA[lca]!, ancB[lca]!, _genderOf(g, bId)),
      related: true,
    );
  }

  // No blood relation: detect relation by marriage (B is spouse of a blood
  // relative of A, or vice-versa).
  for (final s in g.spousesOf[bId] ?? const []) {
    if (_ancestors(g, s).keys.any(ancA.containsKey)) {
      return const Kinship(label: 'related by marriage', related: true);
    }
  }
  for (final s in g.spousesOf[aId] ?? const []) {
    if (_ancestors(g, s).keys.any(ancB.containsKey)) {
      return const Kinship(label: 'related by marriage', related: true);
    }
  }

  return const Kinship(label: 'not directly related', related: false);
}
