import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../profile/profile.dart';
import '../profile/student_profile.dart';
import 'matchmaking_api.dart';

part 'matchmaking_widgets.dart';
part 'matchmaking_lists.dart';
part 'matched_partners.dart';

class MatchmakingPage extends StatefulWidget {
  const MatchmakingPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    this.api,
  });
  final String apiBaseUrl;
  final String accessToken;
  final MatchmakingApi? api;
  @override
  State<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends State<MatchmakingPage> {
  late final _api =
      widget.api ?? MatchmakingApi(widget.apiBaseUrl, widget.accessToken);
  StudentProfile? _profile;
  List<Recommendation> _students = [];
  final _criteria = <String>{'courses', 'interests'};
  final _sessionSkipped = <String>{};
  final _sentInvitations = <String>{};
  bool _busy = true;
  bool _swiping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _loadProfile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _api.ownProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find() async {
    if (_busy || _criteria.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final students = await _api.find(
        _criteria.length == 2 ? 'both' : _criteria.single,
      );
      if (mounted) {
        setState(() {
          _students = students
              .where((r) => !_sessionSkipped.contains(r.profile.userId))
              .toList();
          _swiping = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip() {
    if (_busy || _students.isEmpty) return;
    setState(() {
      _sessionSkipped.add(_students.first.profile.userId);
      _students.removeAt(0);
    });
  }

  Future<void> _saveChoice(String status) async {
    if (_busy || _students.isEmpty) return;
    final id = _students.first.profile.userId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveChoice(id, status);
      if (!mounted) return;
      setState(() => _students.removeAt(0));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'interested'
                ? 'Added to Interested.'
                : 'Added to Uninterested.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendInvitation() async {
    if (_busy || _students.isEmpty) return;
    final id = _students.first.profile.userId;
    if (_sentInvitations.contains(id)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await _api.sendInvitation(id);
      if (!mounted) return;
      setState(() => _sentInvitations.add(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _exit() => setState(() {
    _swiping = false;
    _students = [];
    _sessionSkipped.clear();
    _error = null;
  });

  Future<void> _viewProfile() async {
    if (_busy || _students.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _api.profile(_students.first.profile.userId);
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
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savedProfiles(String status) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _SavedProfilesPage(
          api: _api,
          status: status,
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: widget.accessToken,
          onRestored: (id) {
            if (mounted) setState(() => _sessionSkipped.remove(id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarWidget(title: 'Matchmaking'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _swiping ? 'Study buddies' : 'Find study buddies',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_swiping)
              IconButton(
                key: const Key('exit-swiping'),
                tooltip: 'Exit swiping',
                onPressed: _busy ? null : _exit,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_swiping) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('interested-list'),
                  onPressed: _busy ? null : () => _savedProfiles('interested'),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Interested'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('uninterested-list'),
                  onPressed: _busy
                      ? null
                      : () => _savedProfiles('uninterested'),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Uninterested'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('matched-partners'),
            onPressed: _busy
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MatchedPartnersPage(api: _api),
                    ),
                  ),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Matched partners'),
          ),
          const SizedBox(height: 16),
          const Text('Find students with shared courses, interests, or both.'),
          const SizedBox(height: 16),
          if (_profile case final profile?) ...[
            if (profile.courses.isNotEmpty)
              Text('Your courses: ${profile.courses}'),
            if (profile.interests.isNotEmpty)
              Text('Your interests: ${profile.interests}'),
          ],
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                'courses': 'Courses',
                'interests': 'Interests',
              }.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _criteria.contains(entry.key),
                  onSelected: _busy
                      ? null
                      : (selected) => setState(() {
                          selected
                              ? _criteria.add(entry.key)
                              : _criteria.remove(entry.key);
                        }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('find-buddies'),
            onPressed: _busy || _profile == null || _criteria.isEmpty
                ? null
                : _find,
            icon: const Icon(Icons.people_outline),
            label: const Text('Find study buddies'),
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          if (_profile == null)
            TextButton(
              onPressed: _busy ? null : _loadProfile,
              child: const Text('Retry'),
            ),
        ],
        if (_swiping && _students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No more recommendations for this session. Close this view to start a new session.',
              textAlign: TextAlign.center,
            ),
          ),
        if (_swiping && _students.isNotEmpty) ...[
          Text('${_students.length} students to review'),
          const SizedBox(height: 12),
          _StudentCard(
            key: ValueKey(_students.first.profile.userId),
            student: _students.first,
            enabled: !_busy,
            onSwipe: (right) {
              if (right) {
                _saveChoice('interested');
              } else {
                _skip();
              }
            },
            onUninterested: () => _saveChoice('uninterested'),
            onView: _viewProfile,
            onInvite: _sendInvitation,
            invitationSent: _sentInvitations.contains(
              _students.first.profile.userId,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Swipe left to skip for this session. Swipe right to save interest.\nUninterested saves a lasting exclusion.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}
