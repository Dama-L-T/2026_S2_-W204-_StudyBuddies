
import 'package:flutter/material.dart';

import '../widgets/app_bar.dart';
import 'matchmaking_api.dart';

class BlockedStudentsPage extends StatefulWidget {
  const BlockedStudentsPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  final String apiBaseUrl;
  final String accessToken;

  @override
  State<BlockedStudentsPage> createState() => _BlockedStudentsPageState();
}

class _BlockedStudentsPageState extends State<BlockedStudentsPage> {
  late final MatchmakingApi _api;

  List<BlockedStudent> _students = [];
  bool _loading = true;
  String? _error;
  String? _unblockingId;

  @override
  void initState() {
    super.initState();
    _api = MatchmakingApi(widget.apiBaseUrl, widget.accessToken);
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _api.getBlockedStudents();

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _unblockStudent(BlockedStudent student) async {
    if (_unblockingId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock student?'),
        content: Text(
          'Unblock ${student.profile.name.isEmpty ? 'this student' : student.profile.name}? '
          'Matching and chat interactions may become available again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _unblockingId = student.blockedId;
      _error = null;
    });

    try {
      final message = await _api.unblockStudent(student.blockedId);

      if (!mounted) return;

      setState(() {
        _students.removeWhere(
          (item) => item.blockedId == student.blockedId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _unblockingId = null);
      }
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const AppBarWidget(title: 'Blocked Students'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudents,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadStudents,
                      child: const Text('Try again'),
                    ),
                  ],
                  if (_students.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'You have not blocked any students.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  for (final student in _students)
                    Card(
                      key: ValueKey(student.blockedId),
                      color: const Color(0xFF1A1A1A),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_off_outlined),
                        ),
                        title: Text(
                          student.profile.name.isEmpty
                              ? 'Student'
                              : student.profile.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: TextButton(
                          onPressed: _unblockingId != null
                              ? null
                              : () => _unblockStudent(student),
                          child: Text(
                            _unblockingId == student.blockedId
                                ? 'Unblocking...'
                                : 'Unblock',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
