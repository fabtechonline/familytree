import '../tree/domain/family_graph.dart';

/// The computed relationship of personB relative to personA.
class Kinship {
  const Kinship(
      {required this.label, required this.related, this.isTerm = true});
  final String label;
  final bool related;

  /// True when [label] is a kinship noun ("mother-in-law", "first cousin") that
  /// reads as "B is A's <label>"; false for descriptive phrases ("related by
  /// marriage", "not directly related", "the same person").
  final bool isTerm;
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

String _parentInLaw(String? g) => g == 'male'
    ? 'father-in-law'
    : g == 'female'
        ? 'mother-in-law'
        : 'parent-in-law';
String _childInLaw(String? g) => g == 'male'
    ? 'son-in-law'
    : g == 'female'
        ? 'daughter-in-law'
        : 'child-in-law';
String _siblingInLaw(String? g) => g == 'male'
    ? 'brother-in-law'
    : g == 'female'
        ? 'sister-in-law'
        : 'sibling-in-law';
String _stepParent(String? g) => g == 'male'
    ? 'stepfather'
    : g == 'female'
        ? 'stepmother'
        : 'step-parent';
String _stepChild(String? g) => g == 'male'
    ? 'stepson'
    : g == 'female'
        ? 'stepdaughter'
        : 'step-child';

/// Distances (up from a, down from b) to the lowest common ancestor, or null if
/// a and b share no ancestor (i.e. no blood relation).
({int up, int down})? _bloodPair(FamilyGraph g, String a, String b) {
  final ancA = _ancestors(g, a);
  final ancB = _ancestors(g, b);
  String? lca;
  int best = 1 << 30;
  for (final entry in ancA.entries) {
    final db = ancB[entry.key];
    if (db != null && entry.value + db < best) {
      best = entry.value + db;
      lca = entry.key;
    }
  }
  if (lca == null) return null;
  return (up: ancA[lca]!, down: ancB[lca]!);
}

/// Computes how [bId] is related to [aId].
Kinship computeKinship(FamilyGraph g, String aId, String bId) {
  if (aId == bId) {
    return const Kinship(label: 'the same person', related: true, isTerm: false);
  }
  final genderB = _genderOf(g, bId);

  // Direct spouse / partner.
  if ((g.spousesOf[aId] ?? const []).contains(bId)) {
    final term = genderB == 'male'
        ? 'husband'
        : genderB == 'female'
            ? 'wife'
            : 'spouse';
    return Kinship(label: term, related: true);
  }

  // Blood relation.
  final blood = _bloodPair(g, aId, bId);
  if (blood != null) {
    return Kinship(
        label: _labelFor(blood.up, blood.down, genderB), related: true);
  }

  var marriageLink = false;

  // In-law: B is a blood relative of A's spouse.
  for (final s in g.spousesOf[aId] ?? const []) {
    final bp = _bloodPair(g, s, bId);
    if (bp == null) continue;
    marriageLink = true;
    if (bp.up == 1 && bp.down == 0) {
      return Kinship(label: _parentInLaw(genderB), related: true);
    }
    if (bp.up == 1 && bp.down == 1) {
      return Kinship(label: _siblingInLaw(genderB), related: true);
    }
    if (bp.up == 0 && bp.down == 1) {
      return Kinship(label: _stepChild(genderB), related: true);
    }
  }
  // In-law: B is the spouse of a blood relative of A.
  for (final s in g.spousesOf[bId] ?? const []) {
    final bp = _bloodPair(g, aId, s);
    if (bp == null) continue;
    marriageLink = true;
    if (bp.up == 0 && bp.down == 1) {
      return Kinship(label: _childInLaw(genderB), related: true);
    }
    if (bp.up == 1 && bp.down == 1) {
      return Kinship(label: _siblingInLaw(genderB), related: true);
    }
    if (bp.up == 1 && bp.down == 0) {
      return Kinship(label: _stepParent(genderB), related: true);
    }
  }

  return marriageLink
      ? const Kinship(label: 'related by marriage', related: true, isTerm: false)
      : const Kinship(
          label: 'not directly related', related: false, isTerm: false);
}
