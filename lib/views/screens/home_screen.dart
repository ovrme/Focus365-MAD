import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_localizations.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_filter_intent.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../models/task.dart';
import '../widgets/task_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = 'all'; // all, active, completed
  String _sortBy = 'created'; // created, priority, dueDate, name
  String _searchQuery = '';
  bool _isSearching = false;
  // Batch mode
  bool _isBatchMode = false;
  final Set<String> _selectedIds = {};
  // Sections the user has collapsed in this session (no persistence —
  // collapse is a glance-control, not a saved preference).
  final Set<_DateGroup> _collapsedGroups = {};

  List<Task> _getFilteredTasks(TaskViewModel taskVM) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    List<Task> tasks;
    switch (_filter) {
      case 'all':
        tasks = List.from(taskVM.tasks);
        break;
      case 'active':
        tasks = taskVM.activeTasks;
        break;
      case 'completed':
        tasks = taskVM.completedTasks;
        break;
      case 'assignedToMe':
        final myUid = context.read<AuthViewModel>().user?.uid;
        tasks = myUid == null
            ? <Task>[]
            : taskVM.tasks.where((t) => t.assigneeId == myUid).toList();
        break;
      case 'today':
        tasks = taskVM.tasks.where((t) {
          final d = t.dueDate;
          if (d == null) return false;
          return d.year == startOfToday.year &&
              d.month == startOfToday.month &&
              d.day == startOfToday.day;
        }).toList();
        break;
      case 'important':
        tasks = taskVM.tasks.where((t) => t.priority == 3).toList();
        break;
      case 'thisWeek':
        tasks = taskVM.tasks.where((t) {
          final d = t.dueDate;
          if (d == null) return false;
          return !d.isBefore(startOfToday) && d.isBefore(endOfWeek);
        }).toList();
        break;
      default:
        // category:<name> and project:<id> come from drawer taps via
        // HomeFilterIntent. Plain 'all' (or anything unrecognized) falls
        // through to the unfiltered list.
        if (_filter.startsWith('category:')) {
          final cat = _filter.substring('category:'.length);
          tasks = taskVM.tasks.where((t) => t.category == cat).toList();
        } else if (_filter.startsWith('project:')) {
          final pid = _filter.substring('project:'.length);
          tasks = taskVM.tasks.where((t) => t.projectId == pid).toList();
        } else {
          tasks = List.from(taskVM.tasks);
        }
    }

    if (_searchQuery.isNotEmpty) {
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'priority':
        tasks.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'dueDate':
        tasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'name':
        tasks.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default: // 'created' - newest first (default from Firestore)
        break;
    }

    return tasks;
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedIds.clear();
    });
  }

  void _batchComplete() {
    final taskVM = context.read<TaskViewModel>();
    for (final id in _selectedIds) {
      try {
        final task = taskVM.tasks.firstWhere((t) => t.id == id);
        if (!task.isCompleted) {
          taskVM.toggleComplete(id);
        }
      } catch (_) {
        // Task may have been deleted elsewhere, skip it
      }
    }
    _exitBatchMode();
  }

  void _batchDelete() {
    final l = AppLocalizations.of(context);
    final taskVM = context.read<TaskViewModel>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('deleteTask')),
        content: Text(
            '${l.get('batchDeleteConfirm')} ${_selectedIds.length} ${l.get('tasks')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final id in _selectedIds) {
                taskVM.deleteTask(id);
              }
              _exitBatchMode();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l.get('deleteConfirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    // Pull and apply any pending filter intent (e.g. drawer tap). Done in a
    // post-frame callback so we don't call setState during build.
    final intent = context.watch<HomeFilterIntent>();
    final pending = intent.consume();
    if (pending != null && pending != _filter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _filter = pending);
      });
    }
    final tasks = _getFilteredTasks(taskVM);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    final activeDrawerFilter = _drawerFilterLabel(_filter, l);

    return Column(
      children: [
        // Active drawer filter banner — only when a category:/project: filter
        // is in play, since those don't map to any visible chip.
        if (activeDrawerFilter != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt,
                    size: 16,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeDrawerFilter,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _filter = 'all'),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),

        // Batch mode toolbar
        if (_isBatchMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} ${l.get('selected')}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.check_circle),
                  tooltip: l.get('markComplete'),
                  onPressed:
                      _selectedIds.isNotEmpty ? _batchComplete : null,
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: theme.colorScheme.error),
                  tooltip: l.get('deleteConfirm'),
                  onPressed:
                      _selectedIds.isNotEmpty ? _batchDelete : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitBatchMode,
                ),
              ],
            ),
          ),

        // Search bar
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.get('searchTasks'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  }),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

        // Filter chips + sort + search + batch toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(l.get('all')),
                        selected: _filter == 'all',
                        onSelected: (_) => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.today, size: 16),
                        label: Text(l.get('today')),
                        selected: _filter == 'today',
                        onSelected: (_) =>
                            setState(() => _filter = 'today'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.priority_high, size: 16),
                        label: Text(l.get('important')),
                        selected: _filter == 'important',
                        onSelected: (_) =>
                            setState(() => _filter = 'important'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.date_range, size: 16),
                        label: Text(l.get('thisWeek')),
                        selected: _filter == 'thisWeek',
                        onSelected: (_) =>
                            setState(() => _filter = 'thisWeek'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l.get('active')),
                        selected: _filter == 'active',
                        onSelected: (_) => setState(() => _filter = 'active'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l.get('done')),
                        selected: _filter == 'completed',
                        onSelected: (_) =>
                            setState(() => _filter = 'completed'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.person_pin, size: 16),
                        label: Text(l.get('assignedToMe')),
                        selected: _filter == 'assignedToMe',
                        onSelected: (_) =>
                            setState(() => _filter = 'assignedToMe'),
                      ),
                    ],
                  ),
                ),
              ),
              // Sort button
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: l.get('sortBy'),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'created',
                    child: _sortMenuItem(
                        Icons.access_time, l.get('sortCreated'), 'created'),
                  ),
                  PopupMenuItem(
                    value: 'priority',
                    child: _sortMenuItem(
                        Icons.flag, l.get('sortPriority'), 'priority'),
                  ),
                  PopupMenuItem(
                    value: 'dueDate',
                    child: _sortMenuItem(
                        Icons.calendar_today, l.get('sortDueDate'), 'dueDate'),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: _sortMenuItem(
                        Icons.sort_by_alpha, l.get('sortName'), 'name'),
                  ),
                ],
              ),
              if (!_isSearching)
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => setState(() => _isSearching = true),
                ),
              // Batch mode toggle
              IconButton(
                icon: Icon(
                  _isBatchMode ? Icons.checklist : Icons.checklist_outlined,
                  size: 20,
                ),
                tooltip: l.get('batchMode'),
                onPressed: () => setState(() {
                  _isBatchMode = !_isBatchMode;
                  _selectedIds.clear();
                }),
              ),
            ],
          ),
        ),

        // Task summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${taskVM.activeTasks.length} ${l.get('active').toLowerCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${taskVM.completedTasks.length} ${l.get('completed').toLowerCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Task list
        Expanded(
          child: taskVM.isLoading
              ? const Center(child: CircularProgressIndicator())
              : tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'completed'
                                ? l.get('noCompletedTasks')
                                : l.get('noTasksYet'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        final authVM = context.read<AuthViewModel>();
                        final userId = authVM.user?.uid;
                        if (userId != null) {
                          await context.read<TaskViewModel>().loadTasks(userId);
                        }
                      },
                      child: _shouldGroupByDate()
                          ? _buildSectionedList(context, taskVM, tasks)
                          : _buildFlatList(context, taskVM, tasks),
                    ),
        ),
      ],
    );
  }

  /// Date-grouped layout makes sense when the user is browsing their
  /// open work across the full task list. Smart filters (Today, Important,
  /// This week) are already date-scoped or attribute-scoped, so a flat list
  /// reads better. Search / batch / completed / assigned are "find this
  /// thing" contexts where grouping just adds noise.
  bool _shouldGroupByDate() {
    if (_searchQuery.isNotEmpty) return false;
    if (_isBatchMode) return false;
    const flatFilters = {
      'completed',
      'assignedToMe',
      'today',
      'important',
      'thisWeek',
    };
    if (flatFilters.contains(_filter)) return false;
    // Drawer-driven category/project filters: "find this category" mode.
    if (_filter.startsWith('category:')) return false;
    if (_filter.startsWith('project:')) return false;
    return true;
  }

  Widget _buildFlatList(
    BuildContext context,
    TaskViewModel taskVM,
    List<Task> tasks,
  ) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) =>
          _buildTaskTile(context, theme, taskVM, tasks[index]),
    );
  }

  Widget _buildSectionedList(
    BuildContext context,
    TaskViewModel taskVM,
    List<Task> tasks,
  ) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final groups = _groupByDate(tasks);

    // Order matches a daily-planner reading flow: what's wrong (overdue),
    // what's today, what's tomorrow, then progressively further out.
    const order = [
      _DateGroup.overdue,
      _DateGroup.today,
      _DateGroup.tomorrow,
      _DateGroup.thisWeek,
      _DateGroup.later,
      _DateGroup.noDate,
    ];

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _TodayHeader(
            activeToday: groups[_DateGroup.today]?.length ?? 0,
            overdue: groups[_DateGroup.overdue]?.length ?? 0,
            l: l,
          ),
        ),
      ),
    ];

    for (final group in order) {
      final groupTasks = groups[group] ?? const <Task>[];
      if (groupTasks.isEmpty) continue;
      final collapsed = _collapsedGroups.contains(group);
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(
                label: _sectionLabel(group, l),
                count: groupTasks.length,
                collapsed: collapsed,
                tone: group == _DateGroup.overdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                onTap: () => setState(() {
                  if (collapsed) {
                    _collapsedGroups.remove(group);
                  } else {
                    _collapsedGroups.add(group);
                  }
                }),
              ),
            ),
          ),
        ),
      );
      if (!collapsed) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: groupTasks.length,
              itemBuilder: (context, i) =>
                  _buildTaskTile(context, theme, taskVM, groupTasks[i]),
            ),
          ),
        );
      }
    }

    // Bottom breathing room so the FAB doesn't cover the last card.
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 80)));

    return CustomScrollView(
      // Keeps RefreshIndicator pull-down working even when the list is short.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    ThemeData theme,
    TaskViewModel taskVM,
    Task task,
  ) {
    if (_isBatchMode) {
      final isSelected = _selectedIds.contains(task.id);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color:
            isSelected ? theme.colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedIds.remove(task.id);
            } else {
              _selectedIds.add(task.id);
            }
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => setState(() {
                    if (isSelected) {
                      _selectedIds.remove(task.id);
                    } else {
                      _selectedIds.add(task.id);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: TaskCard(
        key: ValueKey(task.id),
        task: task,
        onToggle: () => taskVM.toggleComplete(task.id),
        onTap: () => _showTaskDetail(context, task),
        onDelete: () => _undoableDelete(context, task),
        onLongPress: () => _enterBatchModeWith(task.id),
      ),
    );
  }

  void _enterBatchModeWith(String taskId) {
    setState(() {
      _isBatchMode = true;
      _selectedIds.add(taskId);
    });
  }

  /// Human-readable label for category:/project: filters set via the drawer.
  /// Returns null when the active filter has its own visible chip (so we
  /// don't double-up on UI affordances).
  String? _drawerFilterLabel(String filter, AppLocalizations l) {
    if (filter.startsWith('category:')) {
      return l.format('categoryFilter',
          {'name': filter.substring('category:'.length)});
    }
    if (filter.startsWith('project:')) {
      final id = filter.substring('project:'.length);
      final name = context
          .read<ProjectViewModel>()
          .projects
          .where((p) => p.id == id)
          .map((p) => p.name)
          .firstOrNull;
      return l.format('projectFilter', {'name': name ?? id});
    }
    return null;
  }

  Map<_DateGroup, List<Task>> _groupByDate(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(const Duration(days: 7));

    final groups = <_DateGroup, List<Task>>{};
    for (final task in tasks) {
      final group = _classify(task, today, tomorrow, endOfWeek);
      groups.putIfAbsent(group, () => []).add(task);
    }
    // Within each section, the earliest due time floats to the top
    // (matches how every planner app sorts its day view).
    for (final list in groups.values) {
      list.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    }
    return groups;
  }

  _DateGroup _classify(
    Task task,
    DateTime today,
    DateTime tomorrow,
    DateTime endOfWeek,
  ) {
    if (task.dueDate == null) return _DateGroup.noDate;
    final due = task.dueDate!;
    final dueDay = DateTime(due.year, due.month, due.day);
    if (!task.isCompleted && dueDay.isBefore(today)) {
      return _DateGroup.overdue;
    }
    if (dueDay == today) return _DateGroup.today;
    if (dueDay == tomorrow) return _DateGroup.tomorrow;
    if (dueDay.isBefore(endOfWeek)) return _DateGroup.thisWeek;
    return _DateGroup.later;
  }

  String _sectionLabel(_DateGroup group, AppLocalizations l) {
    switch (group) {
      case _DateGroup.overdue:
        return l.get('overdue');
      case _DateGroup.today:
        return l.get('today');
      case _DateGroup.tomorrow:
        return l.get('tomorrow');
      case _DateGroup.thisWeek:
        return l.get('thisWeek');
      case _DateGroup.later:
        return l.get('later');
      case _DateGroup.noDate:
        return l.get('noDate');
    }
  }

  Widget _sortMenuItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
        if (_sortBy == value) ...[
          const Spacer(),
          Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
        ],
      ],
    );
  }

  void _showTaskDetail(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TaskDetailSheet(task: task),
    );
  }

  void _undoableDelete(BuildContext context, Task task) {
    final l = AppLocalizations.of(context);
    final taskVM = context.read<TaskViewModel>();
    taskVM.deleteTask(task.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.title} ${l.get('deleted')}'),
        action: SnackBarAction(
          label: l.get('undo'),
          onPressed: () => taskVM.addTask(task),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

enum _DateGroup { overdue, today, tomorrow, thisWeek, later, noDate }

class _TodayHeader extends StatelessWidget {
  final int activeToday;
  final int overdue;
  final AppLocalizations l;

  const _TodayHeader({
    required this.activeToday,
    required this.overdue,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    final bits = <String>[];
    bits.add(activeToday == 1
        ? l.get('tasksTodayOne')
        : l.format('tasksTodayOther', {'count': activeToday}));
    if (overdue > 0) {
      bits.add(overdue == 1
          ? l.get('overdueOne')
          : l.format('overdueOther', {'count': overdue}));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bits.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: overdue > 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: overdue > 0 ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color tone;
  final bool collapsed;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.tone,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Inherits the surface color from the wrapping Container in the
    // delegate so it occludes scrolled content while pinned.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.expand_more, size: 18, color: tone),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  static const double _height = 48;

  _SectionHeaderDelegate({required this.child});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: _height,
      child: Material(
        color: Colors.transparent,
        // Subtle shadow appears once content scrolls under the pinned header
        // so it visually separates from the list below.
        elevation: overlapsContent ? 2 : 0,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) => child != old.child;
}

class _TaskDetailSheet extends StatelessWidget {
  final Task task;
  const _TaskDetailSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final priorityLabels = {
      1: l.get('low'),
      2: l.get('medium'),
      3: l.get('high'),
    };
    final priorityColors = {
      1: Colors.green,
      2: Colors.orange,
      3: Colors.red,
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (task.taskColor != null) ...[
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: task.taskColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColors[task.priority]!
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priorityLabels[task.priority]!,
                    style: TextStyle(
                      color: priorityColors[task.priority],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task.description.isNotEmpty) ...[
              Text(task.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.category, size: 16),
                  label: Text(task.category),
                ),
                if (task.dueDate != null)
                  Chip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    ),
                  ),
                Chip(
                  avatar: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  label: Text(task.isCompleted
                      ? l.get('completed')
                      : l.get('active')),
                ),
                if (task.recurrenceRule != null)
                  Chip(
                    avatar: const Icon(Icons.repeat, size: 16),
                    label: Text(task.recurrenceRule!.toDisplayString()),
                  ),
              ],
            ),
            if (task.subTasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.get('subtasks'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...task.subTasks.map((sub) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      sub.isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    title: Text(
                      sub.title,
                      style: TextStyle(
                        decoration: sub.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  )),
            ],
            if (task.attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.get('attachments'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...task.attachments.map((att) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      att.startsWith('http') ? Icons.link : Icons.note,
                      size: 20,
                    ),
                    title:
                        Text(att, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/add-task', extra: task);
                    },
                    icon: const Icon(Icons.edit),
                    label: Text(l.get('editTask')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final priorityNames = {
                        1: l.get('low'),
                        2: l.get('medium'),
                        3: l.get('high'),
                      };
                      final text =
                          '${task.title}\n${task.description.isNotEmpty ? '${task.description}\n' : ''}${l.get('priority')}: ${priorityNames[task.priority]}\n${l.get('category')}: ${task.category}';
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                    icon: const Icon(Icons.share),
                    label: Text(l.get('shareTask')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
