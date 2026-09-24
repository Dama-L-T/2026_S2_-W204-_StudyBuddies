part of 'schedule.page.dart';

class _ScheduleCalendar extends StatelessWidget {
  const _ScheduleCalendar({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: CalendarDatePicker(
        initialDate: selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        onDateChanged: onDateSelected,
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

class _AddScheduleButton extends StatelessWidget {
  const _AddScheduleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      tooltip: 'Add schedule item',
      iconSize: 28,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(56),
        shape: const CircleBorder(),
      ),
    );
  }
}

class ScheduleItemDetailScreen extends StatelessWidget {
  const ScheduleItemDetailScreen({super.key, required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isAssignment = item.itemType == 'Assignment';
    final status = item.status.toLowerCase() == 'completed'
        ? 'Completed'
        : 'Pending';
    final urgency = _assignmentUrgencyLabel(item.priority);

    return Scaffold(
      appBar: const AppBarWidget(title: 'Schedule Details', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(
                label: Text(item.itemType),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (isAssignment) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(status), visualDensity: VisualDensity.compact),
                if (urgency.isNotEmpty)
                  Chip(
                    label: Text(urgency),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _StudyItemDetail(
            icon: Icons.calendar_today,
            label: isAssignment ? 'Due date' : 'Date',
            value: item.date,
          ),
          _StudyItemDetail(
            icon: Icons.schedule,
            label: isAssignment ? 'Due time' : 'Time',
            value: item.time,
          ),
          if (isAssignment && urgency.isNotEmpty)
            _StudyItemDetail(
              icon: Icons.priority_high,
              label: 'Urgency',
              value: urgency,
            ),
          if (!isAssignment && item.location.trim().isNotEmpty)
            _StudyItemDetail(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: item.location,
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, _ScheduleItemDetailAction.edit),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, _ScheduleItemDetailAction.delete),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyItemCard extends StatelessWidget {
  const _StudyItemCard({
    required this.item,
    required this.onTap,
  });

  final StudyItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAssignment = item.itemType == 'Assignment';
    final urgency = _assignmentUrgencyLabel(item.priority);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(item.itemType),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (isAssignment)
                    Chip(
                      label: Text(
                        item.status.toLowerCase() == 'completed'
                            ? 'Completed'
                            : 'Pending',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isAssignment && urgency.isNotEmpty)
                    Chip(
                      label: Text(urgency),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
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
              if (!isAssignment && item.location.trim().isNotEmpty)
                _StudyItemDetail(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: item.location,
                ),
            ],
          ),
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
