import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/label_viewmodel.dart';
import '../viewmodels/note_viewmodel.dart';
import '../viewmodels/project_viewmodel.dart';
import '../viewmodels/shared_list_viewmodel.dart';
import '../viewmodels/task_viewmodel.dart';
import '../viewmodels/user_profile_viewmodel.dart';

/// Loads per-user data and (re)binds Firestore listeners for [userId].
/// Must run after EVERY successful sign-in — both the splash auto-resume
/// path and a fresh login from the login screen — otherwise the home
/// screen keeps showing the previous account's data until the app is
/// restarted.
Future<void> bootstrapUserSession(
  BuildContext context,
  String userId,
) async {
  final taskVM = context.read<TaskViewModel>();
  final categoryVM = context.read<CategoryViewModel>();
  final projectVM = context.read<ProjectViewModel>();
  final labelVM = context.read<LabelViewModel>();
  final noteVM = context.read<NoteViewModel>();
  final sharedListVM = context.read<SharedListViewModel>();
  final profileVM = context.read<UserProfileViewModel>();
  final authVM = context.read<AuthViewModel>();

  try {
    await Future.wait([
      taskVM.loadTasks(userId),
      categoryVM.loadCategories(userId),
      projectVM.loadProjects(userId),
      labelVM.loadLabels(userId),
    ]);
  } catch (e) {
    debugPrint('Bootstrap data load error: $e');
  }

  projectVM.listenToProjects(userId);
  labelVM.listenToLabels(userId);
  noteVM.listenToNotes(userId);

  // Fire-and-forget — old reminders re-armed under the new scheduler.
  // ignore: unawaited_futures
  NotificationService().migrateLegacyRemindersIfNeeded(
    userId: userId,
    tasks: taskVM.tasks,
  );

  sharedListVM.listen(userId);
  if (authVM.user != null) profileVM.upsertSelf(authVM.user!);
  taskVM.setSharedListIds(sharedListVM.memberListIds);
}
