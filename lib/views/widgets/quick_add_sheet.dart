import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/reminder.dart';
import '../../models/task.dart';
import '../../utils/app_localizations.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';

/// Result emitted by [QuickAddSheet] so the caller can decide whether to
/// quick-save the task or hand it off to the full editor for more options.
class QuickAddResult {
  final Task task;
  final bool openEditor;

  const QuickAddResult({required this.task, this.openEditor = false});
}

/// Fast-capture sheet — title + due date pill + priority. Mirrors the
/// "quick add" pattern in most daily-planner apps so users don't have to
/// open the full editor for the common case.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _titleController = TextEditingController();
  DateTime? _dueDate;
  int _priority = 2;

  @override
  void initState() {
    super.initState();
    // Seed with the user's default priority — saves a tap for users who
    // configured it in settings.
    _priority = context.read<SettingsViewModel>().defaultPriority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _setDate(DateTime? value) {
    setState(() => _dueDate = value);
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    final combined = time == null
        ? DateTime(picked.year, picked.month, picked.day)
        : DateTime(picked.year, picked.month, picked.day, time.hour,
            time.minute);
    _setDate(combined);
  }

  Task _buildTask(BuildContext context) {
    final uid = context.read<AuthViewModel>().user?.uid;
    final settings = context.read<SettingsViewModel>();
    final offset = settings.defaultReminderOffsetMinutes;

    // Apply the default reminder when the user configured one and the
    // task carries a due date. Mirror of the AddTaskScreen behavior so
    // quick-add and full-editor stay consistent.
    final reminders = (offset != null && _dueDate != null)
        ? <TaskReminder>[
            TaskReminder(
              id: const Uuid().v4(),
              fireAt: _dueDate!.subtract(Duration(minutes: offset)),
              offsetMinutesBeforeDue: offset,
            ),
          ]
        : const <TaskReminder>[];

    return Task(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      category: settings.defaultCategory,
      userId: uid,
      reminders: reminders,
    );
  }

  bool get _isValid => _titleController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Lift the sheet above the keyboard so the title field stays visible.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_isValid) _save(context);
                },
                decoration: InputDecoration(
                  hintText: l.get('whatNeedsDoing'),
                  border: InputBorder.none,
                ),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _DatePill(
                      label: l.get('today'),
                      icon: Icons.today,
                      selected: _isSameDay(_dueDate, DateTime.now()),
                      onTap: () => _setDate(_endOfTodayIfNoTime()),
                    ),
                    const SizedBox(width: 8),
                    _DatePill(
                      label: l.get('tomorrow'),
                      icon: Icons.event,
                      selected: _isSameDay(
                          _dueDate,
                          DateTime.now().add(const Duration(days: 1))),
                      onTap: () => _setDate(
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DatePill(
                      label: _customLabel(l),
                      icon: Icons.calendar_month,
                      selected: _dueDate != null &&
                          !_isSameDay(_dueDate, DateTime.now()) &&
                          !_isSameDay(_dueDate,
                              DateTime.now().add(const Duration(days: 1))),
                      onTap: _pickCustomDate,
                    ),
                    if (_dueDate != null) ...[
                      const SizedBox(width: 8),
                      _DatePill(
                        label: l.get('noDate'),
                        icon: Icons.cancel_outlined,
                        selected: false,
                        onTap: () => _setDate(null),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text(l.get('low')),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text(l.get('priorityMed')),
                    icon: const Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: 3,
                    label: Text(l.get('high')),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isValid ? () => _openEditor(context) : null,
                    icon: const Icon(Icons.tune),
                    label: Text(l.get('moreOptions')),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isValid ? () => _save(context) : null,
                    icon: const Icon(Icons.check),
                    label: Text(l.get('addTaskAction')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save(BuildContext context) {
    Navigator.of(context).pop(QuickAddResult(task: _buildTask(context)));
  }

  void _openEditor(BuildContext context) {
    // AddTaskScreen treats an empty id as a template/prefill (not an edit),
    // so it generates a fresh UUID on its own save path.
    final template = _buildTask(context).copyWith(id: '');
    Navigator.of(context).pop(
      QuickAddResult(task: template, openEditor: true),
    );
  }

  // If the user picks "Today" without a time, set due to end-of-day so the
  // task lands in the Today section rather than appearing overdue at noon.
  DateTime _endOfTodayIfNoTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _customLabel(AppLocalizations l) {
    final d = _dueDate;
    if (d == null) return l.get('pickDate');
    if (_isSameDay(d, DateTime.now())) return l.get('pickDate');
    if (_isSameDay(d, DateTime.now().add(const Duration(days: 1)))) {
      return l.get('pickDate');
    }
    final hasTime = d.hour != 0 || d.minute != 0;
    final dayLabel = DateFormat.MMMd().format(d);
    return hasTime ? '$dayLabel · ${DateFormat.jm().format(d)}' : dayLabel;
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DatePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 16,
          color: selected
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onSurfaceVariant),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
