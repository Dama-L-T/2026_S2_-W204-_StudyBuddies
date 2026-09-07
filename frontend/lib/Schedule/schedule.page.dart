import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_bar.dart';

class StudyItem {
  const StudyItem({
    required this.itemType,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
  });

  final String itemType;
  final String title;
  final String date;
  final String time;
  final String location;

  factory StudyItem.fromJson(Map<String, dynamic> json) {
    return StudyItem(
      itemType: json['item_type']?.toString() ?? 'Study item',
      title: json['title']?.toString() ?? 'Untitled study item',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? 'Location TBC',
    );
  }
}

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({
    super.key,
    this.apiBaseUrl = 'http://127.0.0.1:8000',
    this.accessToken,
    this.scheduleItems,
  });

  final String apiBaseUrl;
  final String? accessToken;
  final Future<List<StudyItem>>? scheduleItems;

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  late final Future<List<StudyItem>> _scheduleItems;

  @override
  void initState() {
    super.initState();
    _scheduleItems = widget.scheduleItems ?? _fetchScheduleItems();
  }

  Future<List<StudyItem>> _fetchScheduleItems() async {
    final uri = Uri.parse('${widget.apiBaseUrl}/schedule');

    final response = await http.get(
      uri,
      headers: widget.accessToken == null
          ? null
          : {'Authorization': 'Bearer ${widget.accessToken}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Could not load upcoming study items');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Unexpected schedule response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StudyItem.fromJson)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Scheduler'),
      body: FutureBuilder<List<StudyItem>>(
        future: _scheduleItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _SchedulerMessage(
              icon: Icons.error_outline,
              title: 'Schedule unavailable',
              message: 'Check that the FastAPI backend is running.',
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const _SchedulerMessage(
              icon: Icons.event_available,
              title: 'No upcoming study items',
              message: 'Scheduled sessions will appear here when added.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _SchedulerHeader();
              }

              final item = items[index - 1];
              return _StudyItemCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _SchedulerMessage extends StatelessWidget {
  const _SchedulerMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulerHeader extends StatelessWidget {
  const _SchedulerHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming study items',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _StudyItemCard extends StatelessWidget {
  const _StudyItemCard({required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(item.itemType),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 12),
            _StudyItemDetail(
              icon: Icons.calendar_today,
              label: 'Date',
              value: item.date,
            ),
            _StudyItemDetail(
              icon: Icons.schedule,
              label: 'Time',
              value: item.time,
            ),
            _StudyItemDetail(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: item.location,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyItemDetail extends StatelessWidget {
  const _StudyItemDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
