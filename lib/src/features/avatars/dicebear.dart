/// DiceBear illustrated-avatar helpers (matches the web app's lib/avatar.ts).
/// Renders the same image on web + mobile via the free DiceBear PNG API.
const _dicebear = 'https://api.dicebear.com/9.x';
const avatarStyle = 'adventurer';

// Curated builder palettes (hex without '#').
const skinTones = ['f2d3b1', 'ecad80', 'eeb592', 'd08b5b', '9e5622', '763900'];
const hairColors = ['0e0e0e', '3a2a1d', '6a4e35', '796a45', 'b9a05f', 'e5c07b', 'ac6511', 'cb6820', 'afafaf', 'dba3be'];
const hairStyles = ['short01', 'short02', 'short04', 'short07', 'short11', 'short16', 'long01', 'long07', 'long13', 'long20'];

/// Build a DiceBear PNG URL from an avatar config map ({style, seed, options}).
String dicebearUrl(Map<String, dynamic> config, {int size = 160}) {
  final style = (config['style'] as String?) ?? avatarStyle;
  final parts = <String>['size=$size'];
  final seed = config['seed'];
  if (seed != null) parts.add('seed=${Uri.encodeQueryComponent(seed.toString())}');
  final options = (config['options'] as Map?)?.cast<String, dynamic>() ?? const {};
  options.forEach((k, v) {
    if (v is List) {
      for (final x in v) {
        parts.add('$k=${Uri.encodeQueryComponent(x.toString())}');
      }
    } else if (v != null && v.toString().isNotEmpty) {
      parts.add('$k=${Uri.encodeQueryComponent(v.toString())}');
    }
  });
  return '$_dicebear/$style/png?${parts.join('&')}';
}
