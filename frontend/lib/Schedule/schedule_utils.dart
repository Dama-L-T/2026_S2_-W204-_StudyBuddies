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
