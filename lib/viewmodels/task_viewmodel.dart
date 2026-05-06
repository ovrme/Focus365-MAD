import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/activity.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/task_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';

class TaskViewModel extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final CacheService _cacheService = CacheService();
  final NotificationService _notificationService = NotificationService();
  final StreakService _streakService = StreakService();
  final ActivityService _activityService = ActivityService();

  /// Callback triggered when a task is completed (for confetti)
  VoidCallback? onTaskCompleted;

  List<Task> _tasks = [];
  List<Task> _personalTasks = [];
  List<Task> _sharedTasks = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _streamSub;
  StreamSubscription? _sharedStreamSub;
  String? _currentUserId;
  List<String> _sharedListIds = const [];

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Task> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();
  List<Task> get activeTasks => _tasks.where((t) => !t.isCompleted).toList();

  List<Task> getTasksByCategory(String category) =>
      _tasks.where((t) => t.category == category).toList();

  List<Task> getTasksByProject(String? projectId) =>
      _tasks.where((t) => t.projectId == projectId).toList();

  List<Task> getTasksByLabel(String labelId) =>
      _tasks.where((t) => t.labelIds.contains(labelId)).toList();

  List<Task> getTasksForDate(DateTime date) {
    return _tasks.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
  }

  /// Tasks completed on a specific date (uses completedAt)
  List<Task> getCompletedOnDate(DateTime date) {
    return _tasks.where((t) {
      if (!t.isCompleted || t.completedAt == null) return false;
      return t.completedAt!.year == date.year &&
          t.completedAt!.month == date.month &&
          t.completedAt!.day == date.day;
    }).toList();
  }

  Map<DateTime, List<Task>> get tasksByDate {
    final map = <DateTime, List<Task>>{};
    for (final task in _tasks) {
      if (task.dueDate != null) {
        final dateKey = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        map.putIfAbsent(dateKey, () => []).add(task);
      }
    }
    return map;
  }

  /// Start real-time sync with Firestore
  void startRealTimeSync(String userId) {
    _currentUserId = userId;
    _streamSub?.cancel();
    _streamSub = _taskService.streamTasks(userId).listen(
      (tasks) {
        _personalTasks = tasks;
        _rebuildMergedTasks();
        _isLoading = false;
        _error = null;
        _cacheService.cacheTasks(_tasks);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Task stream error: $e');
        if (_tasks.isEmpty) {
          _error = 'Failed to sync tasks.';
        }
        _isLoading = false;
        notifyListeners();
        // Retry after delay
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentUserId != null) {
            startRealTimeSync(_currentUserId!);
          }
        });
      },
    );
  }

  /// Update the set of shared lists this user belongs to. Re-subscribes the
  /// shared-task stream and merges results into [tasks].
  void setSharedListIds(List<String> listIds) {
    final next = List<String>.from(listIds)..sort();
    final prev = List<String>.from(_sharedListIds)..sort();
    if (next.length == prev.length &&
        List.generate(next.length, (i) => next[i] == prev[i]).every((x) => x)) {
      return;
    }
    _sharedListIds = listIds;
    _sharedStreamSub?.cancel();

    if (listIds.isEmpty) {
      _sharedTasks = const [];
      _rebuildMergedTasks();
      notifyListeners();
      return;
    }

    _sharedStreamSub = _taskService.streamTasksForLists(listIds).listen(
      (tasks) {
        _sharedTasks = tasks;
        _rebuildMergedTasks();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Shared task stream error: $e');
      },
    );
  }

  void _rebuildMergedTasks() {
    final byId = <String, Task>{};
    for (final t in _personalTasks) {
      byId[t.id] = t;
    }
    for (final t in _sharedTasks) {
      // Shared stream wins on conflict (same task may appear in both when the
      // creator is also a member).
      byId[t.id] = t;
    }
    _tasks = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> loadTasks(String userId) async {
    _isLoading = true;
    _error = null;
    _currentUserId = userId;
    // Scope local caches to this user so a different account can't read them.
    _cacheService.setUserId(userId);
    _streakService.setUserId(userId);
    notifyListeners();

    // Load cached data first for fast display
    try {
      final cached = await _cacheService.getCachedTasks();
      if (cached.isNotEmpty && _tasks.isEmpty) {
        _tasks = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (_) {}

    // Sync any pending offline operations
    await _syncPendingOperations();

    // Then start real-time sync
    startRealTimeSync(userId);
  }

  /// Sync pending offline operations when back online
  Future<void> _syncPendingOperations() async {
    try {
      final pendingOps = await _cacheService.getPendingOperations();
      if (pendingOps.isEmpty) return;

      for (final op in pendingOps) {
        try {
          switch (op.type) {
            case OperationType.add:
              if (op.taskData != null) {
                await _taskService.addTask(Task.fromJson(op.taskData!));
              }
            case OperationType.update:
              if (op.taskData != null) {
                await _taskService.updateTask(Task.fromJson(op.taskData!));
              }
            case OperationType.delete:
              await _taskService.deleteTask(op.taskId);
            case OperationType.toggleComplete:
              final isCompleted = op.taskData?['isCompleted'] as bool? ?? false;
              await _taskService.toggleComplete(op.taskId, isCompleted);
          }
        } catch (_) {
          // Skip failed individual ops, continue with rest
        }
      }
      await _cacheService.clearPendingOperations();
    } catch (_) {}
  }

  /// Called by ConnectivityService when connection is restored
  Future<void> onReconnected() async {
    if (_currentUserId == null) return;
    await _syncPendingOperations();
    startRealTimeSync(_currentUserId!);
  }

  Future<void> addTask(Task task) async {
    try {
      _tasks.insert(0, task);
      notifyListeners();
      await _taskService.addTask(task);
      await _cacheService.cacheTasks(_tasks);
      if (task.dueDate != null || task.reminders.isNotEmpty) {
        await _notificationService.scheduleTaskReminder(task);
      }
      _logActivity(task, ActivityType.created);
      if (task.assigneeId != null) {
        _logActivity(task, ActivityType.assigned, meta: {
          'assigneeId': task.assigneeId,
        });
      }
    } catch (e) {
      // Queue for offline sync
      await _cacheService.queueOperation(PendingOperation(
        type: OperationType.add,
        taskId: task.id,
        taskData: task.toJson(),
      ));
      await _cacheService.cacheTasks(_tasks);
    }
  }

  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    final previous = _tasks[index];
    try {
      _tasks[index] = task;
      notifyListeners();
      await _taskService.updateTask(task);
      await _cacheService.cacheTasks(_tasks);
      // Cancel the previously scheduled slots (knows old reminder ids) before
      // re-scheduling, so renamed/removed reminders don't fire stale.
      await _notificationService.cancelRemindersForTask(previous);
      if (task.dueDate != null || task.reminders.isNotEmpty) {
        await _notificationService.scheduleTaskReminder(task);
      }
      _logEditEvents(previous, task);
    } catch (e) {
      // Queue for offline sync instead of reverting
      await _cacheService.queueOperation(PendingOperation(
        type: OperationType.update,
        taskId: task.id,
        taskData: task.toJson(),
      ));
      await _cacheService.cacheTasks(_tasks);
    }
  }

  Future<void> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final removed = _tasks[index];
    try {
      _tasks.removeAt(index);
      notifyListeners();
      await _taskService.deleteTask(taskId);
      await _cacheService.cacheTasks(_tasks);
      await _notificationService.cancelRemindersForTask(removed);
      _logActivity(removed, ActivityType.deleted);
    } catch (e) {
      await _cacheService.queueOperation(PendingOperation(
        type: OperationType.delete,
        taskId: taskId,
      ));
      await _cacheService.cacheTasks(_tasks);
    }
  }

  Future<void> toggleComplete(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;
    notifyListeners();

    try {
      await _taskService.toggleComplete(taskId, task.isCompleted);
      // Also update completedAt in Firestore
      await _taskService.updateTask(task);
      await _cacheService.cacheTasks(_tasks);
      _logActivity(
        task,
        task.isCompleted ? ActivityType.completed : ActivityType.uncompleted,
      );

      if (task.isCompleted) {
        await _notificationService.cancelRemindersForTask(task);
        await _streakService.recordCompletion();
        onTaskCompleted?.call();
        // Handle recurring task: create next occurrence
        if (task.recurrenceRule != null && task.dueDate != null) {
          await _createNextRecurrence(task);
        }
      }
    } catch (e) {
      await _cacheService.queueOperation(PendingOperation(
        type: OperationType.toggleComplete,
        taskId: taskId,
        taskData: {'isCompleted': task.isCompleted},
      ));
      await _cacheService.cacheTasks(_tasks);
    }
  }

  /// Create the next occurrence of a recurring task. Reminders carry forward
  /// with fresh ids (so they don't share OS notification slots with the
  /// completed parent) and shifted by the same delta as the due date.
  Future<void> _createNextRecurrence(Task completedTask) async {
    final nextDate =
        completedTask.recurrenceRule!.nextOccurrence(completedTask.dueDate!);
    if (nextDate == null) return;

    final shift = nextDate.difference(completedTask.dueDate!);
    final nextReminders = completedTask.reminders
        .map((r) => TaskReminder(
              id: const Uuid().v4(),
              fireAt: r.fireAt.add(shift),
              offsetMinutesBeforeDue: r.offsetMinutesBeforeDue,
              // Snooze is per-occurrence — the user can snooze again if they
              // want to push the new occurrence's reminder.
            ))
        .toList();

    final nextTask = completedTask.copyWith(
      id: const Uuid().v4(),
      isCompleted: false,
      dueDate: nextDate,
      createdAt: DateTime.now(),
      clearCompletedAt: true,
      reminders: nextReminders,
    );
    await addTask(nextTask);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all in-memory state and active subscriptions. Call on signOut so
  /// the next account does not see the previous user's data.
  void reset() {
    _streamSub?.cancel();
    _sharedStreamSub?.cancel();
    _streamSub = null;
    _sharedStreamSub = null;
    _tasks = [];
    _personalTasks = [];
    _sharedTasks = [];
    _sharedListIds = const [];
    _currentUserId = null;
    _isLoading = false;
    _error = null;
    onTaskCompleted = null;
    notifyListeners();
  }

  void _logActivity(
    Task task,
    ActivityType type, {
    Map<String, dynamic> meta = const {},
  }) {
    final listId = task.sharedListId;
    final actor = _currentUserId;
    if (listId == null || actor == null) return;
    // Fire-and-forget; ActivityService swallows errors internally.
    _activityService.log(
      listId: listId,
      actorId: actor,
      type: type,
      taskId: task.id,
      taskTitle: task.title,
      meta: meta,
    );
  }

  void _logEditEvents(Task previous, Task next) {
    if (next.sharedListId == null) return;

    if (previous.assigneeId != next.assigneeId) {
      if (next.assigneeId != null) {
        _logActivity(next, ActivityType.assigned, meta: {
          'assigneeId': next.assigneeId,
          if (previous.assigneeId != null)
            'previousAssigneeId': previous.assigneeId,
        });
      } else {
        _logActivity(next, ActivityType.unassigned, meta: {
          'previousAssigneeId': previous.assigneeId,
        });
      }
    }

    final contentChanged = previous.title != next.title ||
        previous.description != next.description ||
        previous.dueDate != next.dueDate ||
        previous.priority != next.priority;
    if (contentChanged) {
      _logActivity(next, ActivityType.edited);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _sharedStreamSub?.cancel();
    super.dispose();
  }
}
