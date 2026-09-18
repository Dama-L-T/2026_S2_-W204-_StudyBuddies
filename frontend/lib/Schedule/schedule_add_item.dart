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
