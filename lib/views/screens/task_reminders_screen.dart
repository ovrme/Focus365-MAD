import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/reminder.dart';
import '../../models/task.dart';
import '../../viewmodels/task_viewmodel.dart';

/// Manage the multi-reminder list attached to a single task.
///
/// Reads the live task from [TaskViewModel] by id (so external updates from
/// the Firestore stream stay reflected) and writes back via
/// `taskVM.updateTask(...)`, which handles cancel + reschedule of OS-level
/// notification slots.
class TaskRemindersScreen extends StatelessWidget {
  final String taskId;

  const TaskRemindersScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    final task = taskVM.tasks
        .cast<Task?>()
        .firstWhere((t) => t?.id == taskId, orElse: () => null);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: const Center(child: Text('Task not found.')),
      );
    }

    final reminders = [...task.reminders]
      ..sort((a, b) => a.effectiveFireAt.compareTo(b.effectiveFireAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.title,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: reminders.isEmpty
          ? _EmptyState(onAdd: () => _showAddSheet(context, task))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reminders.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ReminderTile(
                task: task,
                reminder: reminders[i],
                onSnooze: (delta) => _snooze(context, task, reminders[i], delta),
                onDelete: () => _delete(context, task, reminders[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, task),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add reminder'),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, Task task) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddReminderSheet(dueDate: task.dueDate),
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final reminder = TaskReminder(
      id: const Uuid().v4(),
      fireAt: picked,
      offsetMinutesBeforeDue: task.dueDate?.difference(picked).inMinutes,
    );
    final updated =
        task.copyWith(reminders: [...task.reminders, reminder]);
    await context.read<TaskViewModel>().updateTask(updated);
  }

  Future<void> _snooze(
    BuildContext context,
    Task task,
    TaskReminder reminder,
    Duration delta,
  ) async {
    final snoozed = reminder.copyWith(
      snoozedUntil: DateTime.now().add(delta),
    );
    final updated = task.copyWith(
      reminders: task.reminders
          .map((r) => r.id == reminder.id ? snoozed : r)
          .toList(),
    );
    await context.read<TaskViewModel>().updateTask(updated);
  }

  Future<void> _delete(
    BuildContext context,
    Task task,
    TaskReminder reminder,
  ) async {
    final updated = task.copyWith(
      reminders: task.reminders.where((r) => r.id != reminder.id).toList(),
    );
    await context.read<TaskViewModel>().updateTask(updated);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap “Add reminder” to be notified before this task is due.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Task task;
  final TaskReminder reminder;
  final void Function(Duration) onSnooze;
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.task,
    required this.reminder,
    required this.onSnooze,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    final fireAt = reminder.effectiveFireAt;
    final isPast = fireAt.isBefore(DateTime.now());

    return ListTile(
      leading: Icon(
        isPast ? Icons.history : Icons.alarm,
        color: isPast
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(fmt.format(fireAt)),
      subtitle: _subtitle(context),
      trailing: PopupMenuButton<_ReminderAction>(
        onSelected: (a) {
          switch (a) {
            case _ReminderAction.snooze10m:
              onSnooze(const Duration(minutes: 10));
            case _ReminderAction.snooze1h:
              onSnooze(const Duration(hours: 1));
            case _ReminderAction.snooze1d:
              onSnooze(const Duration(days: 1));
            case _ReminderAction.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _ReminderAction.snooze10m,
            child: Text('Snooze 10 min'),
          ),
          PopupMenuItem(
            value: _ReminderAction.snooze1h,
            child: Text('Snooze 1 hour'),
          ),
          PopupMenuItem(
            value: _ReminderAction.snooze1d,
            child: Text('Snooze 1 day'),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _ReminderAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget? _subtitle(BuildContext context) {
    final pieces = <String>[];
    if (reminder.snoozedUntil != null) {
      pieces.add('Snoozed');
    }
    final offset = reminder.offsetMinutesBeforeDue;
    if (offset != null && offset > 0) {
      pieces.add(_formatOffset(offset));
    }
    if (pieces.isEmpty) return null;
    return Text(pieces.join(' · '));
  }

  String _formatOffset(int minutes) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return days == 1 ? '1 day before due' : '$days days before due';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour before due' : '$hours hours before due';
    }
    return '$minutes min before due';
  }
}

enum _ReminderAction { snooze10m, snooze1h, snooze1d, delete }

class _AddReminderSheet extends StatefulWidget {
  final DateTime? dueDate;
  const _AddReminderSheet({required this.dueDate});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  @override
  Widget build(BuildContext context) {
    final due = widget.dueDate;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'When should we remind you?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (due != null) ...[
              _preset('At due time', due),
              _preset('5 minutes before',
                  due.subtract(const Duration(minutes: 5))),
              _preset('1 hour before',
                  due.subtract(const Duration(hours: 1))),
              _preset('1 day before',
                  due.subtract(const Duration(days: 1))),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Pick a custom date & time'),
              onTap: _pickCustom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _preset(String label, DateTime when) {
    final past = when.isBefore(DateTime.now());
    return ListTile(
      leading: const Icon(Icons.alarm),
      title: Text(label),
      subtitle: Text(DateFormat.yMMMd().add_jm().format(when)),
      enabled: !past,
      onTap: past ? null : () => Navigator.of(context).pop(when),
    );
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    );
    if (time == null) return;
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
      return;
    }
    Navigator.of(context).pop(picked);
  }
}
