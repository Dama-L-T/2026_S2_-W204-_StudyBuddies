import 'dart:convert';

import 'package:http/http.dart' as http;

import 'notifications_service.dart';

final reminderSyncService = ReminderSyncService();

class ReminderSyncService {
  Future<void> syncUpcomingReminders({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/schedule/reminders'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      return;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return;
    }

    await notificationService.cancelScheduleNotifications();

    for (final row in decoded.whereType<Map<String, dynamic>>()) {
      final reminder = _ServerReminder.fromJson(row);
      if (reminder == null) {
        continue;
      }

      final isAssignment = reminder.targetType == 'assignment';
      await notificationService.scheduleNotification(
        id: notificationService.notificationIdFromText(
          '${reminder.targetType}:${reminder.targetId}:${reminder.minutesBefore}',
        ),
        title: isAssignment ? 'Assignment reminder' : 'Event reminder',
        body: isAssignment
            ? '${reminder.title} is due ${_reminderLeadTimeLabel(reminder.minutesBefore)}.'
            : '${reminder.title} starts ${_reminderLeadTimeLabel(reminder.minutesBefore)}.',
        scheduledTime: reminder.remindAt,
        payload: isAssignment
            ? notificationService.assignmentPayload(reminder.targetId)
            : notificationService.eventPayload(reminder.targetId),
      );
    }
  }
}

class _ServerReminder {
  const _ServerReminder({
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.minutesBefore,
    required this.remindAt,
  });

  final String targetType;
  final String targetId;
  final String title;
  final int minutesBefore;
  final DateTime remindAt;

  static _ServerReminder? fromJson(Map<String, dynamic> json) {
    final targetType = json['target_type']?.toString();
    final targetId = json['target_id']?.toString();
    final title = json['title']?.toString();
    final minutesBefore = int.tryParse(json['minutes_before'].toString());
    final remindAt = DateTime.tryParse(json['remind_at']?.toString() ?? '');

    if (targetType != 'assignment' && targetType != 'event') {
      return null;
    }

    if (targetId == null ||
        targetId.isEmpty ||
        title == null ||
        title.isEmpty ||
        minutesBefore == null ||
        remindAt == null) {
      return null;
    }

    final normalizedTargetType = targetType == 'assignment'
        ? 'assignment'
        : 'event';

    return _ServerReminder(
      targetType: normalizedTargetType,
      targetId: targetId,
      title: title,
      minutesBefore: minutesBefore,
      remindAt: remindAt,
    );
  }
}

String _reminderLeadTimeLabel(int minutesBefore) {
  if (minutesBefore == 0) {
    return 'now';
  }

  if (minutesBefore >= 1440 && minutesBefore % 1440 == 0) {
    final days = minutesBefore ~/ 1440;
    if (days == 7) {
      return 'in 1 week';
    }

    return 'in $days day${days == 1 ? '' : 's'}';
  }

  if (minutesBefore >= 60 && minutesBefore % 60 == 0) {
    final hours = minutesBefore ~/ 60;
    return 'in $hours hour${hours == 1 ? '' : 's'}';
  }

  return 'in $minutesBefore minute${minutesBefore == 1 ? '' : 's'}';
}
