import 'package:go_router/go_router.dart';
import '../models/task.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/onboarding_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/main_screen.dart';
import '../views/screens/add_task_screen.dart';
import '../views/screens/settings_screen.dart';
import '../views/screens/help_screen.dart';
import '../views/screens/project_detail_screen.dart';
import '../views/screens/pomodoro_screen.dart';
import '../views/screens/kanban_screen.dart';
import '../views/screens/shared_lists_screen.dart';
import '../views/screens/shared_list_activity_screen.dart';
import '../views/screens/task_reminders_screen.dart';
import '../views/screens/notes_screen.dart';
import '../views/screens/search_screen.dart';

GoRouter createAppRouter(AuthViewModel authVM) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authVM,
    redirect: (context, state) {
      final isAuthenticated = authVM.isAuthenticated;
      final currentPath = state.matchedLocation;

      // Allow splash and onboarding without auth
      if (currentPath == '/' || currentPath == '/onboarding') {
        return null;
      }

      // Allow login page without auth
      if (currentPath == '/login') {
        // If already authenticated, redirect to home
        if (isAuthenticated) return '/home';
        return null;
      }

      // All other routes require authentication
      if (!isAuthenticated) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/add-task',
        name: 'addTask',
        builder: (context, state) {
          final editTask = state.extra as Task?;
          return AddTaskScreen(editTask: editTask);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/pomodoro',
        name: 'pomodoro',
        builder: (context, state) => const PomodoroScreen(),
      ),
      GoRoute(
        path: '/kanban',
        name: 'kanban',
        builder: (context, state) => const KanbanScreen(),
      ),
      GoRoute(
        path: '/shared-lists',
        name: 'sharedLists',
        builder: (context, state) => const SharedListsScreen(),
      ),
      GoRoute(
        path: '/shared-lists/:id/activity',
        name: 'sharedListActivity',
        builder: (context, state) => SharedListActivityScreen(
          listId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/project/:id',
        name: 'projectDetail',
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return ProjectDetailScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/task/:id/reminders',
        name: 'taskReminders',
        builder: (context, state) => TaskRemindersScreen(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/notes',
        name: 'notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
}
