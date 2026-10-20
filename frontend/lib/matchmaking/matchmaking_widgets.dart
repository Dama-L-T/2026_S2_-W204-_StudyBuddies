part of 'matchmaking.page.dart';

class _StudentCard extends StatefulWidget {
  const _StudentCard({
    super.key,
    required this.student,
    required this.enabled,
    required this.onSwipe,
    required this.onUninterested,
    required this.onView,
    required this.onInvite,
    required this.onBlock,
    required this.invitationSent,
  });
  final Recommendation student;
  final bool enabled;
  final ValueChanged<bool> onSwipe;
  final VoidCallback onUninterested;
  final VoidCallback onView;
  final VoidCallback onInvite;
  final VoidCallback onBlock;
  final bool invitationSent;
  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  double _drag = 0;
  @override
  Widget build(BuildContext context) {
    final profile = widget.student.profile;
    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled
          ? (event) => setState(() => _drag += event.delta.dx)
          : null,
      onHorizontalDragCancel: () => setState(() => _drag = 0),
      onHorizontalDragEnd: widget.enabled
          ? (_) {
              if (_drag.abs() >= 80) widget.onSwipe(_drag > 0);
              setState(() => _drag = 0);
            }
          : null,
      child: Transform.translate(
        offset: Offset(_drag.clamp(-100, 100).toDouble(), 0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: widget.enabled ? widget.onView : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: profile.imageUrl == null
                              ? null
                              : NetworkImage(profile.imageUrl!),
                          onBackgroundImageError: profile.imageUrl == null
                              ? null
                              : (_, _) {},
                          child: profile.imageUrl == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.name.isEmpty ? 'Student' : profile.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Interests',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        profile.interests.isEmpty
                            ? 'No interests added yet.'
                            : profile.interests,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preferences',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        profile.preferences.isEmpty
                            ? 'No preferences added yet.'
                            : profile.preferences,
                      ),
                      const SizedBox(height: 16),
                      const Text('View profile →'),
                    ],
                  ),
                ),
                if (_drag.abs() > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _drag > 0 ? 'Interested' : 'Skip for this session',
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: widget.enabled && !widget.invitationSent
                      ? widget.onInvite
                      : null,
                  child: Text(
                    widget.invitationSent ? 'Request sent' : 'Send request',
                  ),
                ),
                OutlinedButton(
                  onPressed: widget.enabled ? widget.onUninterested : null,
                  child: const Text('Uninterested'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.enabled ? widget.onBlock : null,
                  icon: const Icon(Icons.block),
                  label: const Text('Block student'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
