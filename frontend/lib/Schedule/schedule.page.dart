import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    this.refreshToken,
    this.scheduleItems,
  });

  final String apiBaseUrl;
  final String? accessToken;
  final String? refreshToken;
  final Future<List<StudyItem>>? scheduleItems;

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  final _storage = FlutterSecureStorage();
  late Future<List<StudyItem>> _scheduleItems;
  String? _accessToken;
  String? _refreshToken;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;
    _scheduleItems = widget.scheduleItems ?? _fetchScheduleItems();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Scheduler'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddScheduleItem,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
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
}

class ScheduleItemDraft {
  const ScheduleItemDraft({
    required this.itemType,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
  });

  final String itemType;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final String location;

  Map<String, dynamic> toJson() {
    return {
      'item_type': itemType,
      'title': title,
      'date': _dateForApi(date),
      'time': _timeForApi(time),
      'location': location,
    };
  }
}

class AddScheduleItemScreen extends StatefulWidget {
  const AddScheduleItemScreen({
    super.key,
    required this.apiBaseUrl,
    this.accessToken,
    this.refreshToken,
  });

  final String apiBaseUrl;
  final String? accessToken;
  final String? refreshToken;

  @override
  State<AddScheduleItemScreen> createState() => _AddScheduleItemScreenState();
}

class _AddScheduleItemScreenState extends State<AddScheduleItemScreen> {
  final _storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String? _accessToken;
  String? _refreshToken;
  String _itemType = 'Event';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _isLoading = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const AppBarWidget(
        title: 'Add Schedule Item',
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          children: [
            if (_formError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _itemType,
              dropdownColor: Colors.white,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'Event', child: Text('Event')),
                DropdownMenuItem(
                  value: 'Assignment',
                  child: Text('Assignment'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _itemType = value;

                    if (_itemType == 'Assignment') {
                      _locationController.clear();
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Title',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(hintText: 'Enter title'),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            if (_itemType == 'Event') ...[
              const SizedBox(height: 12),
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextFormField(
                controller: _locationController,
                decoration: _inputDecoration(hintText: 'Enter location'),
                textInputAction: TextInputAction.done,
              ),
            ],
            const SizedBox(height: 18),
            _SchedulePickerTile(
              title: _itemType == 'Assignment' ? 'Due date' : 'Date',
              value: _dateForApi(_date),
              icon: Icons.calendar_today,
              onTap: _pickDate,
            ),
            _SchedulePickerTile(
              title: _itemType == 'Assignment' ? 'Due time' : 'Time',
              value: _time.format(context),
              icon: Icons.schedule,
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Schedule Item'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      initialDate: _date,
    );

    if (value != null) {
      setState(() => _date = value);
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);

    if (value != null) {
      setState(() => _time = value);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _formError = null;
      _isLoading = true;
    });

    final draft = ScheduleItemDraft(
      itemType: _itemType,
      title: _titleController.text.trim(),
      date: _date,
      time: _time,
      location: _locationController.text.trim(),
    );

    try {
      var response = await _postScheduleItem(draft);

      if (response.statusCode == 401 && await _refreshSession()) {
        response = await _postScheduleItem(draft);
      }

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule item added')));
        Navigator.pop(context, true);
      } else {
        setState(() {
          _formError =
              '• ${_scheduleErrorMessage(response.statusCode, response.body)}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to server: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<http.Response> _postScheduleItem(ScheduleItemDraft draft) {
    return http.post(
      Uri.parse('${widget.apiBaseUrl}/schedule'),
      headers: {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode(draft.toJson()),
    );
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

  String _scheduleErrorMessage(int statusCode, String responseBody) {
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
      return 'Could not add schedule item ($statusCode): $fallback';
    }

    return 'Could not add schedule item ($statusCode)';
  }
}

class _SchedulePickerTile extends StatelessWidget {
  const _SchedulePickerTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          title: Text(title),
          subtitle: Text(value),
          trailing: Icon(icon),
          onTap: onTap,
        ),
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
