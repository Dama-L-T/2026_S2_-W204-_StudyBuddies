import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

final notificationService = LocalNotificationService();

enum NotificationTargetType { assignment, event }

class NotificationTarget {
  const NotificationTarget({required this.type, required this.id});

  final NotificationTargetType type;
  final String id;

  bool matches({required String itemType, required String itemId}) {
    return type.name == itemType.toLowerCase() && id == itemId;
  }

  static NotificationTarget? parse(String? payload) {
    if (payload == null) {
      return null;
    }

    final parts = payload.split(':');
    if (parts.length != 2 || parts[1].isEmpty) {
      return null;
    }

    for (final type in NotificationTargetType.values) {
      if (type.name == parts[0]) {
        return NotificationTarget(type: type, id: parts[1]);
      }
    }

    return null;
  }
}

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    this.onNotificationTapped,
  }) : _notifications =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  void Function(String? payload)? onNotificationTapped;

  bool _isInitialised = false;

  Future<void> initialise() async {
    if (_isInitialised) {
      return;
    }

    timezone_data.initializeTimeZones();
    await _setDeviceTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTapped?.call(response.payload);
      },
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _isInitialised = true;
  }

  Future<String?> getLaunchPayload() async {
    await initialise();

    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }

    return details?.notificationResponse?.payload;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialise();

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails(),
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    await initialise();

    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: timezone.TZDateTime.from(scheduledTime, timezone.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await initialise();
    await _notifications.cancel(id: id);
  }

  Future<void> cancelScheduleNotifications() async {
    await initialise();

    final pendingNotifications = await _notifications
        .pendingNotificationRequests();

    for (final notification in pendingNotifications) {
      if (NotificationTarget.parse(notification.payload) != null) {
        await _notifications.cancel(id: notification.id);
      }
    }
  }

  int notificationIdFromText(String value) {
    var hash = 0x811c9dc5;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash & 0x7fffffff;
  }

  String assignmentPayload(String assignmentId) {
    return 'assignment:$assignmentId';
  }

  String eventPayload(String eventId) {
    return 'event:$eventId';
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'study_buddies_notifications',
        'Study Buddies Notifications',
        channelDescription: 'Notifications for assignments and events',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _setDeviceTimeZone() async {
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(currentTimeZone.identifier));
  }
}

const defaultReminderMinuteOptions = [10080, 4320, 1440];
const reminderMinuteOptions = [10080, 4320, 1440];
