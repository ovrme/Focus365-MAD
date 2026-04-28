import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/task_viewmodel.dart';
import 'viewmodels/category_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/project_viewmodel.dart';
import 'viewmodels/label_viewmodel.dart';
import 'viewmodels/shared_list_viewmodel.dart';
import 'viewmodels/user_profile_viewmodel.dart';
import 'viewmodels/note_viewmodel.dart';
import 'viewmodels/home_filter_intent.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all services in parallel for fast startup
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Hive.initFlutter(),
  ]);

  // One-time migration: legacy boxes were globally named, leaking cached
  // data between accounts. Delete them so each user gets a fresh,
  // per-uid box on first login.
  for (final name in const [
    'cached_tasks',
    'pending_operations',
    'streak_data',
  ]) {
    if (await Hive.boxExists(name)) {
      await Hive.deleteBoxFromDisk(name);
    }
  }

  // Init settings and notifications
  final settingsVM = SettingsViewModel();
  await settingsVM.init();
  await NotificationService().init();

  final connectivityService = ConnectivityService();
  final taskVM = TaskViewModel();

  // Wire sync-on-reconnect: when connectivity restored, sync pending ops
  connectivityService.onReconnected = () {
    taskVM.onReconnected();
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider.value(value: taskVM),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider.value(value: settingsVM),
        ChangeNotifierProvider(create: (_) => ProjectViewModel()),
        ChangeNotifierProvider(create: (_) => LabelViewModel()),
        ChangeNotifierProvider(create: (_) => SharedListViewModel()),
        ChangeNotifierProvider(create: (_) => UserProfileViewModel()),
        ChangeNotifierProvider(create: (_) => NoteViewModel()),
        ChangeNotifierProvider(create: (_) => HomeFilterIntent()),
        ChangeNotifierProvider.value(value: connectivityService),
      ],
      child: const Focus24App(),
    ),
  );
}
