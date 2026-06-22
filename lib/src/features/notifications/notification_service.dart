import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../celebrations/celebrations.dart';

/// Schedules on-device reminders for upcoming birthdays and anniversaries.
/// No server/Firebase needed — these fire locally while the app is installed.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'celebrations',
      'Celebrations',
      channelDescription: 'Birthday and anniversary reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> ensureInitialized() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the platform timezone can't be resolved.
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: init);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Replaces all scheduled reminders with ones derived from [items]. Fires at
  /// 9am on the day of each celebration.
  Future<void> scheduleCelebrations(List<Celebration> items) async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _plugin.cancelAll();

    var id = 1;
    final now = tz.TZDateTime.now(tz.local);
    for (final c in items) {
      final when =
          tz.TZDateTime(tz.local, c.date.year, c.date.month, c.date.day, 9);
      if (when.isBefore(now)) continue;
      final isBirthday = c.kind == CelebrationKind.birthday;
      final title = isBirthday
          ? '🎂 ${c.title}\'s birthday'
          : '💍 ${c.title} — anniversary';
      final body = isBirthday
          ? (c.years > 0 ? 'Turning ${c.years} today. Send a greeting!' : 'Today! Send a greeting!')
          : (c.years > 0 ? '${c.years} years today. Send a greeting!' : 'Today! Send a greeting!');
      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // Ignore scheduling failures (e.g. permission denied) — non-critical.
      }
    }
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Side-effect provider: (re)schedules reminders whenever the family's upcoming
/// celebrations change. Watched by the dashboard.
final celebrationSchedulerProvider =
    Provider.family<void, String>((ref, familyId) {
  final service = ref.watch(notificationServiceProvider);
  ref.watch(upcomingCelebrationsProvider(familyId)).whenData((list) {
    service.scheduleCelebrations(list);
  });
});
