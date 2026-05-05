import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _tasksRef => _firestore.collection('tasks');

  /// Real-time stream of user's tasks (personal + tasks they created in shared lists).
  Stream<List<Task>> streamTasks(String userId) {
    return _tasksRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final tasks =
          snap.docs.map((doc) => Task.fromFirestore(doc)).toList();
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    });
  }

  /// Real-time stream of all tasks belonging to the given shared lists.
  /// Firestore `whereIn` is limited to 30 values, so list IDs are chunked.
  Stream<List<Task>> streamTasksForLists(List<String> listIds) {
    if (listIds.isEmpty) return Stream.value(const []);

    final chunks = <List<String>>[];
    for (var i = 0; i < listIds.length; i += 30) {
      chunks.add(listIds.sublist(i, (i + 30).clamp(0, listIds.length)));
    }

    final streams = chunks.map((chunk) => _tasksRef
        .where('sharedListId', whereIn: chunk)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Task.fromFirestore(doc)).toList()));

    // Merge: emit a combined list whenever any chunk updates.
    final controller = StreamController<List<Task>>();
    final latest = List<List<Task>>.filled(chunks.length, const []);
    final subs = <StreamSubscription<List<Task>>>[];

    var i = 0;
    for (final s in streams) {
      final idx = i++;
      subs.add(s.listen((tasks) {
        latest[idx] = tasks;
        final merged = latest.expand((t) => t).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(merged);
      }, onError: controller.addError));
    }

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<List<Task>> getTasks(String userId) async {
    final snapshot = await _tasksRef
        .where('userId', isEqualTo: userId)
        .get();
    final tasks =
        snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  Future<void> addTask(Task task) async {
    await _tasksRef.doc(task.id).set(task.toJson());
  }

  Future<void> updateTask(Task task) async {
    await _tasksRef.doc(task.id).update(task.toJson());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<List<Task>> getTasksByDate(String userId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _tasksRef
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => Task.fromFirestore(doc))
        .where((task) {
      if (task.dueDate == null) return false;
      return !task.dueDate!.isBefore(startOfDay) &&
          task.dueDate!.isBefore(endOfDay);
    }).toList();
  }

  Future<void> toggleComplete(String taskId, bool isCompleted) async {
    await _tasksRef.doc(taskId).update({'isCompleted': isCompleted});
  }

  /// Get tasks by project
  Future<List<Task>> getTasksByProject(
      String userId, String projectId) async {
    final snapshot = await _tasksRef
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => Task.fromFirestore(doc))
        .where((task) => task.projectId == projectId)
        .toList();
  }
}
