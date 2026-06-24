import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_providers.dart';

/// Public app settings (feature flags, announcement, maintenance) read from the
/// `app_settings` table. RLS returns only the public rows to normal users.
class AppSettings {
  const AppSettings({
    this.faceRecognition = true,
    this.aiAvatar = true,
    this.dataExport = true,
    this.announcement = '',
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
  });

  final bool faceRecognition;
  final bool aiAvatar;
  final bool dataExport;
  final String announcement;
  final bool maintenanceEnabled;
  final String maintenanceMessage;

  factory AppSettings.fromRows(List<dynamic> rows) {
    final map = {for (final r in rows) (r as Map)['key'] as String: r['value']};
    final features = (map['features'] as Map?) ?? const {};
    final support = (map['support'] as Map?) ?? const {};
    final maint = (map['maintenance'] as Map?) ?? const {};
    return AppSettings(
      faceRecognition: features['face_recognition'] != false,
      aiAvatar: features['ai_avatar'] != false,
      dataExport: features['data_export'] != false,
      announcement: (support['announcement'] as String?) ?? '',
      maintenanceEnabled: maint['enabled'] == true,
      maintenanceMessage: (maint['message'] as String?) ?? '',
    );
  }
}

final publicSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('app_settings').select('key, value');
  return AppSettings.fromRows(rows as List<dynamic>);
});
