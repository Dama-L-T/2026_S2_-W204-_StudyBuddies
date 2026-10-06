part of 'schedule.page.dart';

class ScheduleItemDraft {
  const ScheduleItemDraft({
    required this.itemType,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.isCompleted,
  });

  final String itemType;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final String location;
  final bool isCompleted;

  Map<String, dynamic> toJson() {
    return {
      'item_type': itemType,
      'title': title,
      'date': _dateForApi(date),
      'time': _timeForApi(time),
      'location': location,
      'is_completed': isCompleted,
    };
  }
}

class AddScheduleItemScreen extends StatefulWidget {
  const AddScheduleItemScreen({
    super.key,
    required this.apiBaseUrl,
    this.accessToken,
    this.refreshToken,
    this.item,
    this.initialDate,
  });

  final String apiBaseUrl;
  final String? accessToken;
  final String? refreshToken;
  final StudyItem? item;
  final DateTime? initialDate;

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
  List<int> _reminderMinutes = defaultReminderMinuteOptions;
  List<int> _savedReminderMinutes = const [];
  bool _isCompleted = false;
  bool _isLoading = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;
    _date = widget.initialDate ?? DateTime.now();

    final item = widget.item;

    if (item != null) {
      _itemType = item.itemType;
      _titleController.text = item.title;

      if (item.itemType == 'Event' && item.location != 'Location TBC') {
        _locationController.text = item.location;
      }

      _date = DateTime.tryParse(item.date) ?? DateTime.now();
      _time = _timeFromScheduleItem(item.time) ?? TimeOfDay.now();
      _isCompleted = item.status.toLowerCase() == 'completed';
      _loadExistingReminderMinutes(item);
    }
  }

  Future<void> _loadExistingReminderMinutes(StudyItem item) async {
    try {
      final minutes = await _fetchReminderMinutes(item);
      if (!mounted) {
        return;
      }

      setState(() {
        _reminderMinutes = minutes;
        _savedReminderMinutes = minutes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reminderMinutes = const [];
        _savedReminderMinutes = const [];
      });
    }
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
      appBar: const AppBarWidget(title: 'Schedule Item', showBackButton: true),
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
              onChanged: widget.item == null
                  ? (value) {
                      if (value != null) {
                        setState(() {
                          _itemType = value;

                          if (_itemType == 'Assignment') {
                            _locationController.clear();
                          } else {
                            _isCompleted = false;
                          }
                        });
                      }
                    }
                  : null,
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
            const SizedBox(height: 12),
            _ReminderPickerTile(
              value: _reminderMinutes,
              onChanged: (minutes) {
                setState(() {
                  _reminderMinutes = minutes;
                });
              },
            ),
            if (_itemType == 'Assignment') ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: CheckboxListTile(
                  value: _isCompleted,
                  onChanged: (value) {
                    setState(() {
                      _isCompleted = value ?? false;
                    });
                  },
                  title: const Text('Completed'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
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
                      : Text(
                          widget.item == null
                              ? 'Add Schedule Item'
                              : 'Save Changes',
                        ),
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
      isCompleted: _itemType == 'Assignment' && _isCompleted,
    );

    try {
      var response = await _saveScheduleItem(draft);

      if (response.statusCode == 401 && await _refreshSession()) {
        response = await _saveScheduleItem(draft);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedItem = _savedItemFromResponse(response, draft);
        if (savedItem != null) {
          final savedReminderMinutes = await _saveReminders(savedItem);
          await _scheduleReminder(savedItem, savedReminderMinutes);
          if (!mounted) return;
        }

        final message = widget.item == null
            ? 'Schedule item added'
            : 'Schedule item updated';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context, true);
      } else {
        setState(() {
          _formError =
              '• ${_scheduleErrorMessage('Could not save schedule item', response.statusCode, response.body)}';
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

  StudyItem? _savedItemFromResponse(
    http.Response response,
    ScheduleItemDraft draft,
  ) {
    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return StudyItem.fromJson(decoded);
    }

    final existingItem = widget.item;
    if (existingItem == null) {
      return null;
    }

    return StudyItem(
      id: existingItem.id,
      itemType: draft.itemType,
      title: draft.title,
      date: _dateForApi(draft.date),
      time: _timeForApi(draft.time),
      location: draft.location,
      status: draft.isCompleted ? 'Completed' : '',
      priority: existingItem.priority,
    );
  }

  Future<void> _scheduleReminder(
    StudyItem item,
    List<int> reminderMinutes,
  ) async {
    final itemDateTime = _dateTimeFromScheduleItem(item);
    if (itemDateTime == null) {
      return;
    }

    final existingReminderMinutes = {
      ..._savedReminderMinutes,
      ..._reminderMinutes,
    };

    for (final minutesBefore in existingReminderMinutes) {
      await notificationService.cancelNotification(
        _notificationIdForScheduleItem(item, minutesBefore),
      );
    }

    if (_isCompletedAssignment(item)) {
      _savedReminderMinutes = const [];
      return;
    }

    final isAssignment = item.itemType.toLowerCase() == 'assignment';

    for (final minutesBefore in reminderMinutes) {
      await notificationService.scheduleNotification(
        id: _notificationIdForScheduleItem(item, minutesBefore),
        title: isAssignment ? 'Assignment reminder' : 'Event reminder',
        body: isAssignment
            ? '${item.title} is due ${_reminderLeadTimeLabel(minutesBefore)}.'
            : '${item.title} starts ${_reminderLeadTimeLabel(minutesBefore)}.',
        scheduledTime: itemDateTime.subtract(Duration(minutes: minutesBefore)),
        payload: isAssignment
            ? notificationService.assignmentPayload(item.id)
            : notificationService.eventPayload(item.id),
      );
    }

    _savedReminderMinutes = reminderMinutes;
    _reminderMinutes = reminderMinutes;
  }

  Future<List<int>> _fetchReminderMinutes(StudyItem item) async {
    var response = await _reminderRequest(item);

    if (response.statusCode == 401 && await _refreshSession()) {
      response = await _reminderRequest(item);
    }

    if (response.statusCode == 404) {
      return const [];
    }

    if (response.statusCode != 200) {
      throw Exception(
        _scheduleErrorMessage(
          'Could not load reminders',
          response.statusCode,
          response.body,
        ),
      );
    }

    return _reminderMinutesFromResponse(response);
  }

  Future<List<int>> _saveReminders(StudyItem item) async {
    final reminderMinutes = _isCompletedAssignment(item)
        ? const <int>[]
        : _sortedReminderMinutes(_reminderMinutes);
    var response = await _reminderRequest(item, reminderMinutes);

    if (response.statusCode == 401 && await _refreshSession()) {
      response = await _reminderRequest(item, reminderMinutes);
    }

    if (response.statusCode != 200) {
      throw Exception(
        _scheduleErrorMessage(
          'Could not save reminders',
          response.statusCode,
          response.body,
        ),
      );
    }

    return _reminderMinutesFromResponse(response);
  }

  Future<http.Response> _reminderRequest(
    StudyItem item, [
    List<int>? reminderMinutes,
  ]) {
    final uri = Uri.parse(
      '${widget.apiBaseUrl}/schedule/${item.itemType.toLowerCase()}/${item.id}/reminders',
    );
    final headers = {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };

    if (reminderMinutes == null) {
      return http.get(uri, headers: headers);
    }

    return http.put(
      uri,
      headers: headers,
      body: jsonEncode({
        'reminders': reminderMinutes
            .map((minutesBefore) => {'minutes_before': minutesBefore})
            .toList(),
      }),
    );
  }

  List<int> _reminderMinutesFromResponse(http.Response response) {
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
  }

  Future<http.Response> _saveScheduleItem(ScheduleItemDraft draft) {
    final item = widget.item;
    final uri = item == null
        ? Uri.parse('${widget.apiBaseUrl}/schedule')
        : Uri.parse(
            '${widget.apiBaseUrl}/schedule/${item.itemType.toLowerCase()}/${item.id}',
          );
    final headers = {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
    final body = jsonEncode(draft.toJson());

    if (item == null) {
      return http.post(uri, headers: headers, body: body);
    }

    return http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      },
      body: body,
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

class _ReminderPickerTile extends StatelessWidget {
  const _ReminderPickerTile({
    required this.value,
    required this.onChanged,
  });

  final List<int> value;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        title: const Text('Reminders'),
        trailing: const Icon(Icons.notifications_outlined),
        onTap: () => _showReminderPicker(context),
      ),
    );
  }

  Future<void> _showReminderPicker(BuildContext context) async {
    final selectedMinutes = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ReminderPickerSheet(initialValue: value),
    );

    if (selectedMinutes != null) {
      onChanged(selectedMinutes);
    }
  }
}

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({required this.initialValue});

  final List<int> initialValue;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late final Set<int> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = widget.initialValue.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...reminderMinuteOptions.map(
            (minutes) => CheckboxListTile(
              value: _selectedValues.contains(minutes),
              title: Text(_reminderOptionLabel(minutes)),
              onChanged: (isSelected) {
                setState(() {
                  if (isSelected == true) {
                    _selectedValues.add(minutes);
                  } else {
                    _selectedValues.remove(minutes);
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Custom reminders',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCustomReminderDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add custom'),
                ),
              ],
            ),
          ),
          ..._customReminderTiles(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _sortedReminderMinutes(_selectedValues),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _customReminderTiles() {
    final customValues = _selectedValues
        .where((minutes) => !reminderMinuteOptions.contains(minutes))
        .toList()
      ..sort((first, second) => second.compareTo(first));

    if (customValues.isEmpty) {
      return const [];
    }

    return customValues
        .map(
          (minutes) => ListTile(
            title: Text(_reminderOptionLabel(minutes)),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove reminder',
              onPressed: () {
                setState(() {
                  _selectedValues.remove(minutes);
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedValues.remove(minutes);
              });
            },
          ),
        )
        .toList();
  }

  Future<void> _openCustomReminderDialog(BuildContext context) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => const _CustomReminderDialog(),
    );

    if (!context.mounted || minutes == null) {
      return;
    }

    setState(() {
      _selectedValues.add(minutes);
    });
  }
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog();

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  int _weeks = 0;
  int _days = 0;
  int _hours = 0;
  int _minutes = 0;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 180,
            width: 320,
            child: Row(
              children: [
                Expanded(
                  child: _CustomReminderPickerColumn(
                    label: 'Weeks',
                    maxValue: 52,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _weeks = value;
                        _errorText = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _CustomReminderPickerColumn(
                    label: 'Days',
                    maxValue: 6,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _days = value;
                        _errorText = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _CustomReminderPickerColumn(
                    label: 'Hours',
                    maxValue: 23,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _hours = value;
                        _errorText = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _CustomReminderPickerColumn(
                    label: 'Minutes',
                    maxValue: 59,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _minutes = value;
                        _errorText = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _addCustomReminder,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _addCustomReminder() {
    final totalMinutes =
        (_weeks * 7 * 24 * 60) +
        (_days * 24 * 60) +
        (_hours * 60) +
        _minutes;

    if (totalMinutes <= 0) {
      setState(() {
        _errorText = 'Enter at least one value.';
      });
      return;
    }

    Navigator.pop(context, totalMinutes);
  }
}

class _CustomReminderPickerColumn extends StatelessWidget {
  const _CustomReminderPickerColumn({
    required this.label,
    required this.maxValue,
    required this.onSelectedItemChanged,
  });

  final String label;
  final int maxValue;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final valueCount = maxValue + 1;
    final initialItem = valueCount * 1000;

    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Expanded(
          child: CupertinoPicker(
            itemExtent: 36,
            magnification: 1.08,
            squeeze: 1.1,
            useMagnifier: true,
            scrollController: FixedExtentScrollController(
              initialItem: initialItem,
            ),
            onSelectedItemChanged: (index) {
              onSelectedItemChanged(index % valueCount);
            },
            children: List.generate(
              valueCount * 2000,
              (index) => Center(
                child: Text('${index % valueCount}', style: textStyle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
