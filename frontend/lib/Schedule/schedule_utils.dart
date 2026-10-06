part of 'schedule.page.dart';

String _dateForApi(DateTime value) {
  return [
    value.year.toString().padLeft(4, '0'),
    value.month.toString().padLeft(2, '0'),
    value.day.toString().padLeft(2, '0'),
  ].join('-');
}

String _timeForApi(TimeOfDay value) {
  return [
    value.hour.toString().padLeft(2, '0'),
    value.minute.toString().padLeft(2, '0'),
  ].join(':');
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

TimeOfDay? _timeFromScheduleItem(String value) {
  final timeText = value.split(' - ').first.trim();
  final parts = timeText.split(':');

  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return TimeOfDay(hour: hour, minute: minute);
}

DateTime? _dateTimeFromScheduleItem(StudyItem item) {
  final date = DateTime.tryParse(item.date);
  final time = _timeFromScheduleItem(item.time);

  if (date == null || time == null) {
    return null;
  }

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

bool _isCompletedAssignment(StudyItem item) {
  return item.itemType.toLowerCase() == 'assignment' &&
      item.status.toLowerCase() == 'completed';
}

String _notificationItemKey(StudyItem item) {
  return '${item.itemType.toLowerCase()}:${item.id}';
}

int _notificationIdForScheduleItem(StudyItem item, int minutesBefore) {
  return notificationService.notificationIdFromText(
    '${_notificationItemKey(item)}:$minutesBefore',
  );
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

List<int> _sortedReminderMinutes(Iterable<int> values) {
  return values.toSet().toList()
    ..sort((first, second) => second.compareTo(first));
}

String _reminderOptionLabel(int minutes) {
  if (minutes == 0) return 'At time';

  var remainingMinutes = minutes;
  final weeks = remainingMinutes ~/ 10080;
  remainingMinutes %= 10080;
  final days = remainingMinutes ~/ 1440;
  remainingMinutes %= 1440;
  final hours = remainingMinutes ~/ 60;
  remainingMinutes %= 60;

  final parts = [
    if (weeks > 0) '$weeks week${weeks == 1 ? '' : 's'}',
    if (days > 0) '$days day${days == 1 ? '' : 's'}',
    if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    if (remainingMinutes > 0)
      '$remainingMinutes min${remainingMinutes == 1 ? '' : 's'}',
  ];

  return parts.join(' ');
}

String _assignmentUrgencyLabel(String priority) {
  final normalized = priority.trim().toLowerCase();

  if (normalized.isEmpty) return '';

  return switch (normalized) {
    'high' => 'High urgency',
    'medium' => 'Medium urgency',
    'low' => 'Low urgency',
    _ => '${normalized[0].toUpperCase()}${normalized.substring(1)} urgency',
  };
}

String _scheduleErrorMessage(
  String fallbackMessage,
  int statusCode,
  String responseBody,
) {
  try {
    final decoded = jsonDecode(responseBody);

    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail']?.toString();

      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
    }
  } catch (_) {
    // Fall through to the generic message when the backend did not return JSON.
  }

  final fallback = responseBody.trim();

  if (fallback.isNotEmpty) {
    return '$fallbackMessage ($statusCode): $fallback';
  }

  return '$fallbackMessage ($statusCode)';
}
