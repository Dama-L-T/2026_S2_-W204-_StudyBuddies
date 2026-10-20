part of 'matchmaking.page.dart';

class _InvitationInbox extends StatefulWidget {
  const _InvitationInbox({required this.api});
  final MatchmakingApi api;
  @override
  State<_InvitationInbox> createState() => _InvitationInboxState();
}

class _InvitationInboxState extends State<_InvitationInbox> {
  List<StudyInvitation> _invitations = [];
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_acting) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invitations = await widget.api.incomingInvitations();
      if (mounted) setState(() => _invitations = invitations);
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

  Future<void> _respond(StudyInvitation invitation, bool accept) async {
    if (_loading || _acting) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await widget.api.respondToInvitation(invitation.id, accept);
      if (!mounted) return;
      setState(
        () => _invitations.removeWhere((item) => item.id == invitation.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation accepted. You can find them in Matched partners.'
                : 'Invitation declined.',
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
  
  Future<void> _blockStudent(StudyInvitation invitation) async {
    if (_loading || _acting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block student?'),
        content: Text(
          'Block ${invitation.profile.name.isEmpty ? 'this student' : invitation.profile.name}? '
          'They will no longer be able to interact with you through matching or chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _acting = true;
      _error = null;
    });

    try {
      final message = await widget.api.blockStudent(
        invitation.profile.userId,
      );

      if (!mounted) return;

      setState(() {
        _invitations.removeWhere(
          (item) => item.id == invitation.id,
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
        setState(() => _acting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarWidget(
      title: 'Incoming invitations',
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
              child: const Text('Refresh invitations'),
            ),
          ],
          if (!_loading && _error == null && _invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No pending invitations.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final invitation in _invitations)
            Card(
              key: ValueKey('invitation-${invitation.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      invitation.profile.name.isEmpty
                          ? 'Student'
                          : invitation.profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (invitation.profile.courses.isNotEmpty)
                      Text(invitation.profile.courses),
                    if (invitation.profile.interests.isNotEmpty)
                      Text(invitation.profile.interests),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton(
                          onPressed: _acting || _loading
                              ? null
                              : () => _respond(invitation, true),
                          child: const Text('Accept'),
                        ),
                        OutlinedButton(
                          onPressed: _acting || _loading
                              ? null
                              : () => _respond(invitation, false),
                          child: const Text('Decline'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _acting || _loading
                              ? null
                              : () => _blockStudent(invitation),
                          icon: const Icon(Icons.block),
                          label: const Text('Block'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
