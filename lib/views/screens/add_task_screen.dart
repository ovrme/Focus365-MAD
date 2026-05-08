import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/reminder.dart';
import '../../models/task.dart';
import '../../models/recurrence.dart';
import '../../utils/app_localizations.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/label_viewmodel.dart';
import '../../viewmodels/shared_list_viewmodel.dart';
import '../../viewmodels/user_profile_viewmodel.dart';
import '../widgets/task_comments_section.dart';

// Predefined colors users can choose from
const List<Color> _taskColors = [
  Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
  Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
  Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
  Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
  Colors.brown, Colors.grey,
];

class AddTaskScreen extends StatefulWidget {
  final Task? editTask;
  const AddTaskScreen({super.key, this.editTask});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subTaskController = TextEditingController();
  final _attachmentController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int _priority = 2;
  String _category = 'General';
  final List<SubTask> _subTasks = [];
  bool _isEditing = false;
  int? _selectedColorValue;
  String? _selectedProjectId;
  String? _selectedSharedListId;
  String? _selectedAssigneeId;
  List<String> _selectedLabelIds = [];
  RecurrenceRule? _recurrenceRule;
  final List<String> _attachments = [];
  String? _selectedEmoji;

  @override
  void initState() {
    super.initState();
    if (widget.editTask != null) {
      final t = widget.editTask!;
      // A task with a non-empty id is a real edit; empty id means template/pre-fill
      _isEditing = t.id.isNotEmpty;
      _titleController.text = t.title;
      _descriptionController.text = t.description;
      _dueDate = t.dueDate;
      if (t.dueDate != null) {
        _dueTime = TimeOfDay.fromDateTime(t.dueDate!);
      }
      _priority = t.priority;
      _category = t.category;
      _subTasks.addAll(t.subTasks);
      _selectedColorValue = t.colorValue;
      _selectedProjectId = t.projectId;
      _selectedSharedListId = t.sharedListId;
      _selectedAssigneeId = t.assigneeId;
      _selectedLabelIds = List.from(t.labelIds);
      _recurrenceRule = t.recurrenceRule;
      _attachments.addAll(t.attachments);
      _selectedEmoji = t.emoji;
    } else {
      // Fresh task with no incoming template — seed from user defaults.
      // (Templates already carry whatever the QuickAddSheet picked.)
      final settings = context.read<SettingsViewModel>();
      _priority = settings.defaultPriority;
      _category = settings.defaultCategory;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _EmojiPickerSheet(current: _selectedEmoji),
    );
    if (!mounted) return;
    if (picked == null) return; // Cancelled — leave as-is.
    // The sheet returns empty string to mean "clear", any other value to set.
    setState(() => _selectedEmoji = picked.isEmpty ? null : picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
      _pickTime();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _dueTime = picked;
        if (_dueDate != null) {
          _dueDate = DateTime(
            _dueDate!.year, _dueDate!.month, _dueDate!.day,
            picked.hour, picked.minute,
          );
        }
      });
    }
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      setState(() {
        _subTasks.add(SubTask(
          id: const Uuid().v4(),
          title: _subTaskController.text.trim(),
        ));
        _subTaskController.clear();
      });
    }
  }

  void _addAttachment() {
    final text = _attachmentController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _attachments.add(text);
        _attachmentController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final taskVM = context.read<TaskViewModel>();
    final authVM = context.read<AuthViewModel>();

    if (authVM.user?.uid == null) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('pleaseSignInToSave'))),
        );
      }
      return;
    }

    // For edits, read the latest version from the viewmodel so fields not
    // surfaced in this form (reminders, emoji, estimatedMinutes,
    // completionNote) survive a re-save — including reminders added via the
    // dedicated reminders screen.
    final latest = _isEditing
        ? taskVM.tasks
            .cast<Task?>()
            .firstWhere((t) => t?.id == widget.editTask!.id,
                orElse: () => widget.editTask)
        : null;

    // Default reminder: only applies on fresh creates, only when the user
    // configured one in settings, only when a due date exists, and only when
    // the form has no other reminders set yet (so we never collide with a
    // user-added reminder via the dedicated reminders screen).
    final settings = context.read<SettingsViewModel>();
    final existingReminders = latest?.reminders ?? const <TaskReminder>[];
    final defaultOffset = settings.defaultReminderOffsetMinutes;
    final shouldInjectDefaultReminder = !_isEditing &&
        existingReminders.isEmpty &&
        defaultOffset != null &&
        _dueDate != null;
    final reminders = shouldInjectDefaultReminder
        ? <TaskReminder>[
            TaskReminder(
              id: const Uuid().v4(),
              fireAt: _dueDate!.subtract(Duration(minutes: defaultOffset)),
              offsetMinutesBeforeDue: defaultOffset,
            ),
          ]
        : existingReminders;

    final task = Task(
      id: _isEditing ? widget.editTask!.id : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      category: _category,
      priority: _priority,
      subTasks: _subTasks,
      userId: authVM.user?.uid,
      colorValue: _selectedColorValue,
      isCompleted: _isEditing ? widget.editTask!.isCompleted : false,
      createdAt: _isEditing ? widget.editTask!.createdAt : DateTime.now(),
      projectId: _selectedProjectId,
      sharedListId: _selectedSharedListId,
      assigneeId: _selectedSharedListId == null ? null : _selectedAssigneeId,
      labelIds: _selectedLabelIds,
      recurrenceRule: _recurrenceRule,
      isRecurring: _recurrenceRule != null,
      attachments: _attachments,
      reminders: reminders,
      // Emoji is form-controlled now; estimatedMinutes/completionNote
      // aren't surfaced anywhere, so they piggyback on the latest snapshot.
      emoji: _selectedEmoji,
      estimatedMinutes: latest?.estimatedMinutes,
      completionNote: latest?.completionNote,
    );

    if (_isEditing) {
      await taskVM.updateTask(task);
    } else {
      await taskVM.addTask(task);
    }

    if (mounted) context.pop();
  }

  void _showRecurrenceDialog() {
    final l = AppLocalizations.of(context);
    RecurrenceType selectedType = _recurrenceRule?.type ?? RecurrenceType.daily;
    int interval = _recurrenceRule?.interval ?? 1;
    List<int> daysOfWeek = List.from(_recurrenceRule?.daysOfWeek ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.get('recurrence')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              SegmentedButton<RecurrenceType>(
                segments: [
                  ButtonSegment(
                    value: RecurrenceType.daily,
                    label: Text(l.get('daily')),
                  ),
                  ButtonSegment(
                    value: RecurrenceType.weekly,
                    label: Text(l.get('weekly')),
                  ),
                  ButtonSegment(
                    value: RecurrenceType.monthly,
                    label: Text(l.get('monthly')),
                  ),
                ],
                selected: {selectedType},
                onSelectionChanged: (s) =>
                    setDialogState(() => selectedType = s.first),
              ),
              const SizedBox(height: 16),

              // Interval
              Row(
                children: [
                  Text('${l.get('every')} '),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      controller: TextEditingController(text: '$interval'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) interval = n;
                      },
                    ),
                  ),
                  Text(' ${_intervalLabel(selectedType, l)}'),
                ],
              ),

              // Days of week for weekly
              if (selectedType == RecurrenceType.weekly) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final dayNames = [
                      l.get('mon'), l.get('tue'), l.get('wed'),
                      l.get('thu'), l.get('fri'), l.get('sat'), l.get('sun'),
                    ];
                    return FilterChip(
                      label: Text(dayNames[i]),
                      selected: daysOfWeek.contains(day),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            daysOfWeek.add(day);
                          } else {
                            daysOfWeek.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _recurrenceRule = null);
                Navigator.pop(ctx);
              },
              child: Text(l.get('noRecurrence')),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _recurrenceRule = RecurrenceRule(
                    type: selectedType,
                    interval: interval,
                    daysOfWeek: daysOfWeek,
                  );
                });
                Navigator.pop(ctx);
              },
              child: Text(l.get('save')),
            ),
          ],
        ),
      ),
    );
  }

  String _intervalLabel(RecurrenceType type, AppLocalizations l) {
    switch (type) {
      case RecurrenceType.daily:
        return l.get('days');
      case RecurrenceType.weekly:
        return l.get('weeks');
      case RecurrenceType.monthly:
        return l.get('months');
      case RecurrenceType.custom:
        return l.get('days');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryViewModel>().categories;
    final projects = context.watch<ProjectViewModel>().projects;
    final labels = context.watch<LabelViewModel>().labels;
    final sharedLists = context.watch<SharedListViewModel>().lists;
    final profileVM = context.watch<UserProfileViewModel>();
    final activeSharedList = _selectedSharedListId == null
        ? null
        : sharedLists
            .where((l) => l.id == _selectedSharedListId)
            .firstOrNull;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l.get('editTask') : l.get('addTask')),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l.get('save')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title (with leading emoji picker)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmojiButton(
                  emoji: _selectedEmoji,
                  onTap: _pickEmoji,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l.get('taskTitle'),
                      hintText: l.get('taskTitleHint'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l.get('titleRequired')
                        : null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l.get('description'),
                hintText: l.get('descriptionHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            // Shared list
            if (sharedLists.isNotEmpty) ...[
              Text(l.get('list'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.get('myTasks')),
                    avatar: const Icon(Icons.person_outline, size: 16),
                    selected: _selectedSharedListId == null,
                    onSelected: (_) =>
                        setState(() => _selectedSharedListId = null),
                  ),
                  ...sharedLists.map((sl) => ChoiceChip(
                        label: Text(sl.name),
                        avatar: const Icon(Icons.group, size: 16),
                        selected: _selectedSharedListId == sl.id,
                        onSelected: (_) => setState(() {
                          _selectedSharedListId = sl.id;
                          // Reset assignee if switching lists & current
                          // assignee isn't a member of the new list.
                          if (_selectedAssigneeId != null &&
                              !sl.memberIds.contains(_selectedAssigneeId)) {
                            _selectedAssigneeId = null;
                          }
                        }),
                      )),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Assignee (only when a shared list is selected)
            if (activeSharedList != null) ...[
              Text(l.get('assignee'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.get('unassigned')),
                    avatar: const Icon(Icons.person_off_outlined, size: 16),
                    selected: _selectedAssigneeId == null,
                    onSelected: (_) =>
                        setState(() => _selectedAssigneeId = null),
                  ),
                  ...activeSharedList.memberIds.map((uid) {
                    return ChoiceChip(
                      label: Text(profileVM.displayName(uid)),
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          profileVM.initials(uid),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      selected: _selectedAssigneeId == uid,
                      onSelected: (_) =>
                          setState(() => _selectedAssigneeId = uid),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Project
            if (projects.isNotEmpty) ...[
              Text(l.get('project'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.get('inbox')),
                    avatar: const Icon(Icons.inbox, size: 16),
                    selected: _selectedProjectId == null,
                    onSelected: (_) =>
                        setState(() => _selectedProjectId = null),
                  ),
                  ...projects.map((p) => ChoiceChip(
                        label: Text(p.name),
                        avatar: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        selected: _selectedProjectId == p.id,
                        onSelected: (_) =>
                            setState(() => _selectedProjectId = p.id),
                      )),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Labels
            if (labels.isNotEmpty) ...[
              Text(l.get('labels'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels
                    .map((label) => FilterChip(
                          label: Text(label.name),
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: label.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          selected: _selectedLabelIds.contains(label.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLabelIds.add(label.id);
                              } else {
                                _selectedLabelIds.remove(label.id);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Task Color
            Text(l.get('taskColor'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedColorValue = null),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColorValue == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        width: _selectedColorValue == null ? 3 : 1,
                      ),
                    ),
                    child: Icon(Icons.block,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                ..._taskColors.map((color) {
                  final colorVal = color.toARGB32();
                  final isSelected = _selectedColorValue == colorVal;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedColorValue = colorVal),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Due Date
            Text(l.get('dueDate'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_dueDate != null
                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                        : l.get('pickDate')),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_dueTime != null
                        ? _dueTime!.format(context)
                        : l.get('setTime')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _dueTime = null;
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Recurrence
            Text(l.get('recurrence'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showRecurrenceDialog,
              icon: const Icon(Icons.repeat),
              label: Text(_recurrenceRule != null
                  ? _recurrenceRule!.toDisplayString()
                  : l.get('noRecurrence')),
            ),
            const SizedBox(height: 20),

            // Reminders — managed on a dedicated screen so the bottom sheet
            // pickers don't have to fight this form's layout. Disabled until
            // the task has been saved (it needs a real id to navigate to).
            Text(l.get('reminders'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _RemindersRow(
              isEditing: _isEditing,
              taskId: _isEditing ? widget.editTask!.id : null,
            ),
            const SizedBox(height: 20),

            // Priority
            Text(l.get('priority'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 1,
                    label: Text(l.get('low')),
                    icon: const Icon(Icons.arrow_downward)),
                ButtonSegment(
                    value: 2,
                    label: Text(l.get('medium')),
                    icon: const Icon(Icons.remove)),
                ButtonSegment(
                    value: 3,
                    label: Text(l.get('high')),
                    icon: const Icon(Icons.arrow_upward)),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 20),

            // Category
            Text(l.get('category'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map((cat) => ChoiceChip(
                        label: Text(cat.name),
                        avatar: Icon(cat.icon, size: 16),
                        selected: _category == cat.name,
                        onSelected: (_) =>
                            setState(() => _category = cat.name),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Attachments (notes/links)
            Text(l.get('attachments'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _attachmentController,
                    decoration: InputDecoration(
                      hintText: l.get('addAttachment'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _addAttachment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addAttachment,
                  icon: const Icon(Icons.attach_file),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._attachments.asMap().entries.map((entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isUrl(entry.value) ? Icons.link : Icons.note,
                    size: 20,
                    color: _isUrl(entry.value)
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _isUrl(entry.value)
                        ? TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          )
                        : null,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _attachments.removeAt(entry.key)),
                  ),
                  onTap: () => _openAttachment(entry.value),
                )),
            const SizedBox(height: 20),

            // Subtasks
            Text(l.get('subtasks'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskController,
                    decoration: InputDecoration(
                      hintText: l.get('addSubtask'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _addSubTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addSubTask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._subTasks.asMap().entries.map((entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: IconButton(
                    icon: Icon(
                      entry.value.isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    onPressed: () => setState(() =>
                        entry.value.isCompleted = !entry.value.isCompleted),
                  ),
                  title: Text(entry.value.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _subTasks.removeAt(entry.key)),
                  ),
                )),

            // Comments (shared tasks only, after first save)
            if (_isEditing && _selectedSharedListId != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TaskCommentsSection(taskId: widget.editTask!.id),
            ],
          ],
        ),
      ),
    );
  }

  bool _isUrl(String text) {
    return text.startsWith('http://') || text.startsWith('https://');
  }

  Future<void> _openAttachment(String value) async {
    if (_isUrl(value)) {
      final uri = Uri.tryParse(value);
      final ok = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $value')),
        );
      }
    } else {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }
}

class _EmojiButton extends StatelessWidget {
  final String? emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: emoji != null
            ? Text(emoji!, style: const TextStyle(fontSize: 28))
            : Icon(
                Icons.add_reaction_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _EmojiPickerSheet extends StatelessWidget {
  final String? current;
  const _EmojiPickerSheet({required this.current});

  // Compact preset set covering most common task themes. Users rarely use
  // an emoji picker for tasks beyond a quick visual marker, so a curated
  // grid is faster than a full-blown picker dialog.
  static const List<String> _presets = [
    '🎯', '🔥', '⭐', '✅', '⚠️', '⏰',
    '💡', '📌', '📚', '💼', '🏠', '🛒',
    '💪', '🍎', '🚗', '✈️', '🎉', '❤️',
    '💰', '🎵', '🎨', '☕', '🐶', '🌱',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l.get('pickEmoji'),
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (current != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, ''),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(l.get('clear')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _presets.map((e) {
                final selected = e == current;
                return InkWell(
                  onTap: () => Navigator.pop(context, e),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemindersRow extends StatelessWidget {
  final bool isEditing;
  final String? taskId;

  const _RemindersRow({required this.isEditing, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!isEditing || taskId == null) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.alarm),
        label: Text(l.get('saveFirstForReminders')),
      );
    }

    final taskVM = context.watch<TaskViewModel>();
    final task = taskVM.tasks
        .cast<Task?>()
        .firstWhere((t) => t?.id == taskId, orElse: () => null);
    final count = task?.reminders.length ?? 0;

    return OutlinedButton.icon(
      onPressed: () => context.pushNamed(
        'taskReminders',
        pathParameters: {'id': taskId!},
      ),
      icon: const Icon(Icons.alarm),
      label: Text(count == 0
          ? l.get('noRemindersTap')
          : count == 1
              ? l.get('reminderOne')
              : l.format('reminderOther', {'count': count})),
    );
  }
}
