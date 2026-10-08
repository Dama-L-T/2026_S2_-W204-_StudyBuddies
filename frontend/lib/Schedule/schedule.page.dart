import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../service/notifications_service.dart';
import '../widgets/app_bar.dart';

part 'schedule_models.dart';
part 'schedule_add_item.dart';
part 'schedule_widgets.dart';
part 'schedule_utils.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({
    super.key,
    this.apiBaseUrl = 'http://127.0.0.1:8000',
    this.accessToken,
    this.refreshToken,
    this.scheduleItems,
    this.notificationTarget,
  });

  final String apiBaseUrl;
  final String? accessToken;
  final String? refreshToken;
  final Future<List<StudyItem>>? scheduleItems;
  final NotificationTarget? notificationTarget;

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  final _storage = FlutterSecureStorage();
  late Future<List<StudyItem>> _scheduleItems;
  String? _accessToken;
  String? _refreshToken;
  NotificationTarget? _pendingNotificationTarget;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;
    _pendingNotificationTarget = widget.notificationTarget;
    _scheduleItems = widget.scheduleItems ?? _fetchScheduleItems();
  }

  @override
  void didUpdateWidget(covariant SchedulerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.notificationTarget != widget.notificationTarget) {
      _pendingNotificationTarget = widget.notificationTarget;
    }

    if (oldWidget.accessToken == widget.accessToken &&
        oldWidget.refreshToken == widget.refreshToken) {
      return;
    }

    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;

    setState(() {
      _scheduleItems = widget.scheduleItems ?? _fetchScheduleItems();
    });
  }

  Future<List<StudyItem>> _fetchScheduleItems() async {
    final uri = Uri.parse('${widget.apiBaseUrl}/schedule');

    var response = await http.get(uri, headers: _authHeaders());

    if (response.statusCode == 401 && await _refreshSession()) {
      response = await http.get(uri, headers: _authHeaders());
    }

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

  Future<void> _openAddScheduleItem() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddScheduleItemScreen(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          initialDate: _selectedDate,
        ),
      ),
    );

    if (added == true && mounted) {
      _accessToken = await _storage.read(key: 'access_token');
      _refreshToken = await _storage.read(key: 'refresh_token');

      setState(() {
        _scheduleItems = _fetchScheduleItems();
      });
    }
  }

  Future<void> _openScheduleItemDetails(StudyItem item) async {
    final action = await Navigator.push<_ScheduleItemDetailAction>(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleItemDetailScreen(item: item),
      ),
    );

    if (!mounted) return;

    if (action == _ScheduleItemDetailAction.edit) {
      await _openEditScheduleItem(item);
    }

    if (action == _ScheduleItemDetailAction.delete) {
      await _deleteScheduleItem(item);
    }
  }

  Future<void> _openEditScheduleItem(StudyItem item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddScheduleItemScreen(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          item: item,
        ),
      ),
    );

    if (updated == true && mounted) {
      _accessToken = await _storage.read(key: 'access_token');
      _refreshToken = await _storage.read(key: 'refresh_token');

      setState(() {
        _scheduleItems = _fetchScheduleItems();
      });
    }
  }

  Future<void> _deleteScheduleItem(StudyItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete "${item.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final reminderMinutes = await _fetchReminderMinutesForItem(item);
    var response = await _deleteScheduleItemRequest(item);

    if (response.statusCode == 401 && await _refreshSession()) {
      response = await _deleteScheduleItemRequest(item);
    }

    if (!mounted) return;

    if (response.statusCode == 204) {
      for (final minutesBefore in reminderMinutes) {
        await notificationService.cancelNotification(
          _notificationIdForScheduleItem(item, minutesBefore),
        );
      }
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule item deleted')));

      setState(() {
        _scheduleItems = _fetchScheduleItems();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _scheduleErrorMessage(
            'Could not delete schedule item',
            response.statusCode,
            response.body,
          ),
        ),
      ),
    );
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 120),
                const _SchedulerMessage(
                  icon: Icons.error_outline,
                  title: 'Schedule unavailable',
                  message: 'Check that the FastAPI backend is running.',
                ),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: _reloadScheduleItems,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final items = snapshot.data ?? [];
          _openPendingNotificationTarget(items);
          final selectedItems = items.where(_isItemOnSelectedDate).toList();

          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScheduleCalendar(
                  selectedDate: _selectedDate,
                  onDateSelected: _selectDate,
                ),
                const SizedBox(height: 24),
                const _SchedulerMessage(
                  icon: Icons.event_available,
                  title: 'No upcoming study items',
                  message: 'Scheduled sessions will appear here when added.',
                ),
                const SizedBox(height: 24),
                Center(
                  child: _AddScheduleButton(onPressed: _openAddScheduleItem),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: selectedItems.isEmpty ? 4 : selectedItems.length + 3,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ScheduleCalendar(
                  selectedDate: _selectedDate,
                  onDateSelected: _selectDate,
                );
              }

              if (index == 1) {
                return const _SchedulerHeader();
              }

              if (selectedItems.isEmpty && index == 2) {
                return const _SchedulerMessage(
                  icon: Icons.event_available,
                  title: 'No items for this date',
                  message: 'Use the plus button to add one.',
                );
              }

              final addButtonIndex = selectedItems.isEmpty
                  ? 3
                  : selectedItems.length + 2;

              if (index == addButtonIndex) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    child: _AddScheduleButton(onPressed: _openAddScheduleItem),
                  ),
                );
              }

              final item = selectedItems[index - 2];
              return _StudyItemCard(
                item: item,
                onTap: () => _openScheduleItemDetails(item),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, String>? _authHeaders() {
    if (_accessToken == null) return null;

    return {'Authorization': 'Bearer $_accessToken'};
  }

  Future<bool> _refreshSession() async {
    final refreshToken =
        _refreshToken ?? await _storage.read(key: 'refresh_token');

    if (refreshToken == null) return false;

    final response = await http.post(
      Uri.parse('${widget.apiBaseUrl}/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode != 200) return false;

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) return false;

    final accessToken = decoded['access_token']?.toString();
    final newRefreshToken = decoded['refresh_token']?.toString();

    if (accessToken == null || newRefreshToken == null) return false;

    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: newRefreshToken);

    _accessToken = accessToken;
    _refreshToken = newRefreshToken;

    return true;
  }

  Future<http.Response> _deleteScheduleItemRequest(StudyItem item) {
    return http.delete(
      Uri.parse(
        '${widget.apiBaseUrl}/schedule/${item.itemType.toLowerCase()}/${item.id}',
      ),
      headers: {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      },
    );
  }

  Future<List<int>> _fetchReminderMinutesForItem(StudyItem item) async {
    try {
      var response = await _reminderRequest(item);

      if (response.statusCode == 401 && await _refreshSession()) {
        response = await _reminderRequest(item);
      }

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const [];
      }

      return _sortedReminderMinutes(
        decoded
            .whereType<Map<String, dynamic>>()
            .map((row) => int.tryParse(row['minutes_before'].toString()))
            .whereType<int>(),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<http.Response> _reminderRequest(StudyItem item) {
    return http.get(
      Uri.parse(
        '${widget.apiBaseUrl}/schedule/${item.itemType.toLowerCase()}/${item.id}/reminders',
      ),
      headers: {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      },
    );
  }

  void _reloadScheduleItems() {
    setState(() {
      _scheduleItems = _fetchScheduleItems();
    });
  }

  bool _isItemOnSelectedDate(StudyItem item) {
    final itemDate = DateTime.tryParse(item.date);

    if (itemDate == null) return false;

    return _isSameDay(itemDate, _selectedDate);
  }

  void _selectDate(DateTime selectedDate) {
    setState(() {
      _selectedDate = _dateOnly(selectedDate);
    });
  }

  void _openPendingNotificationTarget(List<StudyItem> items) {
    final target = _pendingNotificationTarget;
    if (target == null) {
      return;
    }

    StudyItem? targetItem;
    for (final item in items) {
      if (target.matches(itemType: item.itemType, itemId: item.id)) {
        targetItem = item;
        break;
      }
    }

    if (targetItem == null) {
      return;
    }

    final itemToOpen = targetItem;
    _pendingNotificationTarget = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final itemDate = DateTime.tryParse(itemToOpen.date);
      if (itemDate != null) {
        setState(() {
          _selectedDate = _dateOnly(itemDate);
        });
      }

      await _openScheduleItemDetails(itemToOpen);
    });
  }
}
