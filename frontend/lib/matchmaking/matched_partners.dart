part of 'matchmaking.page.dart';

class _MatchedPartnersPage extends StatefulWidget {
  const _MatchedPartnersPage({required this.api});
  final MatchmakingApi api;

  @override
  State<_MatchedPartnersPage> createState() => _MatchedPartnersPageState();
}

class _MatchedPartnersPageState extends State<_MatchedPartnersPage> {
  List<StudentProfile> _partners = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final partners = await widget.api.matchedPartners();
      if (mounted) setState(() => _partners = partners);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarWidget(title: 'Matched partners', showBackButton: true),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Students whose study connections have been accepted.'),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Retry'),
            ),
          ],
          if (!_loading && _error == null && _partners.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matches yet. Your study partners will appear here once a connection is accepted.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final partner in _partners)
            Card(
              key: ValueKey('partner-${partner.userId}'),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: partner.imageUrl == null
                      ? null
                      : NetworkImage(partner.imageUrl!),
                  onBackgroundImageError: partner.imageUrl == null
                      ? null
                      : (_, _) {},
                  child: partner.imageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(partner.name.isEmpty ? 'Student' : partner.name),
                subtitle:
                    [
                      partner.courses,
                      partner.interests,
                    ].where((value) => value.isNotEmpty).isEmpty
                    ? null
                    : Text(
                        [
                          partner.courses,
                          partner.interests,
                        ].where((value) => value.isNotEmpty).join(' · '),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}
