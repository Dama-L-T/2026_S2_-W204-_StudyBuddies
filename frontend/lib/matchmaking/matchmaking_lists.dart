part of 'matchmaking.page.dart';

class _SavedProfilesPage extends StatefulWidget {
  const _SavedProfilesPage({
    required this.api,
    required this.status,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.onRestored,
  });
  final MatchmakingApi api;
  final String status;
  final String apiBaseUrl;
  final String accessToken;
  final ValueChanged<String> onRestored;
  @override
  State<_SavedProfilesPage> createState() => _SavedProfilesPageState();
}

class _SavedProfilesPageState extends State<_SavedProfilesPage> {
  List<StudentProfile> _profiles = [];
  bool _loading = true;
  bool _acting = false;
  Map<String, String> _invitationStatuses = {};
  bool _statusesLoaded = false;
  String? _error;
  bool get _uninterested => widget.status == 'uninterested';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_acting || (_loading && _statusesLoaded)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        widget.api.savedProfiles(widget.status),
        if (!_uninterested) widget.api.invitationStatuses(),
      ]);
      if (mounted) {
        setState(() {
          _profiles = result[0] as List<StudentProfile>;
          _invitationStatuses = _uninterested
              ? {}
              : result[1] as Map<String, String>;
          _statusesLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRemoval(StudentProfile student) async {
    if (_acting || _loading) return;
    final listName = _uninterested ? 'Uninterested' : 'Interested';
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this student from $listName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure?'),
            const SizedBox(height: 8),
            Text(
              'They will appear again in your recommendations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      if (_uninterested) {
        await widget.api.restoreProfile(student.userId);
      } else {
        await widget.api.removeInterest(student.userId);
      }
      if (!mounted) return;
      setState(() => _profiles.removeWhere((p) => p.userId == student.userId));
      widget.onRestored(student.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This student can appear in your next search.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _sendInvitation(StudentProfile student) async {
    if (_acting ||
        _loading ||
        !_statusesLoaded ||
        _error != null ||
        _invitationStatuses.containsKey(student.userId)) {
      return;
    }
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      final message = await widget.api.sendInvitation(student.userId);
      if (!mounted) return;
      setState(() => _invitationStatuses[student.userId] = 'outgoing_pending');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
      try {
        final statuses = await widget.api.invitationStatuses();
        if (mounted) setState(() => _invitationStatuses = statuses);
      } catch (_) {
        // Keep send disabled until a successful refresh.
        if (mounted) setState(() => _statusesLoaded = false);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _invitationLabel(String studentId) =>
      switch (_invitationStatuses[studentId]) {
        'outgoing_pending' => 'Pending invite',
        'incoming_pending' => 'Invitation received',
        'accepted' => 'Matched',
        'declined' => 'Invite declined',
        _ => 'Send invite',
      };

  Future<void> _view(StudentProfile student) async {
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      final profile = await widget.api.profile(student.userId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(
            apiBaseUrl: widget.apiBaseUrl,
            accessToken: widget.accessToken,
            onProfileSaved: () {},
            viewedProfile: profile,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarWidget(
      title: _uninterested ? 'Uninterested' : 'Interested',
      showBackButton: true,
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading || _acting) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _loading || _acting ? null : _load,
              child: const Text('Retry'),
            ),
          ],
          if (!_loading && _error == null && _profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _uninterested
                    ? 'No uninterested students saved.'
                    : 'No interested students saved.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final student in _profiles)
            Card(
              key: ValueKey('saved-${student.userId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    enabled: !_acting,
                    onTap: _acting ? null : () => _view(student),
                    leading: CircleAvatar(
                      backgroundImage: student.imageUrl == null
                          ? null
                          : NetworkImage(student.imageUrl!),
                      onBackgroundImageError: student.imageUrl == null
                          ? null
                          : (_, _) {},
                      child: student.imageUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    trailing: IconButton(
                      key: ValueKey('remove-${student.userId}'),
                      tooltip: _uninterested
                          ? 'Remove from Uninterested'
                          : 'Remove from Interested',
                      onPressed: _acting
                          ? null
                          : () => _confirmRemoval(student),
                      icon: const Icon(Icons.close),
                    ),
                    title: Text(
                      student.name.isEmpty ? 'Student' : student.name,
                    ),
                    subtitle: student.interests.isEmpty
                        ? null
                        : Text(student.interests),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _acting ? null : () => _view(student),
                          child: const Text('View profile'),
                        ),
                        if (!_uninterested)
                          FilledButton(
                            onPressed:
                                _acting ||
                                    _loading ||
                                    !_statusesLoaded ||
                                    _error != null ||
                                    _invitationStatuses.containsKey(
                                      student.userId,
                                    )
                                ? null
                                : () => _sendInvitation(student),
                            child: Text(_invitationLabel(student.userId)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
