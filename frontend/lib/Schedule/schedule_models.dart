part of 'schedule.page.dart';

class StudyItem {
  const StudyItem({
    required this.id,
    required this.itemType,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.status,
    required this.priority,
  });

  final String id;
  final String itemType;
  final String title;
  final String date;
  final String time;
  final String location;
  final String status;
  final String priority;

  factory StudyItem.fromJson(Map<String, dynamic> json) {
    return StudyItem(
      id: json['id']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? 'Study item',
      title: json['title']?.toString() ?? 'Untitled study item',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? 'Location TBC',
      status: json['status']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
    );
  }
}

enum _ScheduleItemDetailAction { edit, delete }
