import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_localizations.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/home_filter_intent.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../widgets/app_background.dart';
import '../widgets/quick_add_sheet.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'projects_screen.dart';
import 'statistics_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late ConfettiController _confettiController;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HomeScreen(),
    ProjectsScreen(),
    CalendarScreen(),
    StatisticsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Listen for task completion to trigger confetti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskVM = context.read<TaskViewModel>();
      taskVM.onTaskCompleted = () {
        _confettiController.play();
      };
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _showQuickAdd(BuildContext context) async {
    final result = await showModalBottomSheet<QuickAddResult>(
      context: context,
      isScrollControlled: true,
      // Sheet handles its own background; transparent base lets the
      // rounded corners + safe-area padding render correctly.
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const QuickAddSheet(),
    );
    if (result == null) return;
    if (!context.mounted) return;
    if (result.openEditor) {
      // Hand the partially-filled task to the full editor as a template.
      context.push('/add-task', extra: result.task);
    } else {
      await context.read<TaskViewModel>().addTask(result.task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = [
      l.get('dashboard'),
      l.get('appName'),
      l.get('projects'),
      l.get('calendar'),
      l.get('statistics'),
      l.get('profile'),
    ];

    return Stack(
      children: [
        AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(titles[_currentIndex]),
              centerTitle: true,
            actions: [
              // Search button
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l.get('search'),
                onPressed: () => context.push('/search'),
              ),
              // Shared lists button
              IconButton(
                icon: const Icon(Icons.workspaces_outline),
                tooltip: l.get('sharedLists'),
                onPressed: () => context.push('/shared-lists'),
              ),
              // Kanban board button
              IconButton(
                icon: const Icon(Icons.view_kanban_outlined),
                tooltip: l.get('kanbanBoard'),
                onPressed: () => context.push('/kanban'),
              ),
              // Notes button
              IconButton(
                icon: const Icon(Icons.sticky_note_2_outlined),
                tooltip: l.get('notes'),
                onPressed: () => context.push('/notes'),
              ),
              // Pomodoro timer button
              IconButton(
                icon: const Icon(Icons.timer_outlined),
                tooltip: l.get('pomodoro'),
                onPressed: () => context.push('/pomodoro'),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          drawer: _AppDrawer(
            currentIndex: _currentIndex,
            onPickTab: (i) {
              Navigator.pop(context); // Close drawer.
              setState(() => _currentIndex = i);
            },
          ),
          body: _screens[_currentIndex],
          floatingActionButton: _currentIndex != 0
              ? FloatingActionButton(
                  onPressed: () => _showQuickAdd(context),
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: l.get('dashb'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.task_alt_outlined),
                selectedIcon: const Icon(Icons.task_alt),
                label: l.get('tasks'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder),
                label: l.get('projects'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: l.get('calendar'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart),
                label: l.get('statistics'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l.get('profile'),
              ),
            ],
          ),
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.amber,
            ],
            numberOfParticles: 20,
            emissionFrequency: 0.05,
            gravity: 0.15,
          ),
        ),
      ],
    );
  }
}

/// App-wide drawer: user header, tab navigation, tools, categories with
/// counts, projects with counts. Tapping a tab item flips the bottom-nav
/// index; tapping a project navigates to the projects tab. Categories are
/// informational (counts only) until a category-filter route exists.
class _AppDrawer extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onPickTab;

  const _AppDrawer({required this.currentIndex, required this.onPickTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final auth = context.watch<AuthViewModel>();
    final taskVM = context.watch<TaskViewModel>();
    final categoryVM = context.watch<CategoryViewModel>();
    final projectVM = context.watch<ProjectViewModel>();

    final user = auth.user;
    final initials = (user?.displayName ?? '?').isNotEmpty
        ? user!.displayName[0].toUpperCase()
        : '?';

    // Counts per category use the merged list (defaults + customs) so the
    // drawer always agrees with the chip picker on the add-task screen.
    final categoryCounts = <String, int>{};
    for (final task in taskVM.tasks) {
      categoryCounts[task.category] =
          (categoryCounts[task.category] ?? 0) + 1;
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              accountName: Text(
                user?.displayName ?? l.get('guestUser'),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              accountEmail: Text(
                user?.email ?? l.get('notSignedIn'),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.8),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.surface,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        initials,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
            ),

            // Tabs.
            _DrawerSection(label: l.get('navigate')),
            _DrawerTile(
              icon: const Icon(Icons.dashboard_outlined),
              label: l.get('dashboard'),
              selected: currentIndex == 0,
              onTap: () => onPickTab(0),
            ),
            _DrawerTile(
              icon: const Icon(Icons.task_alt_outlined),
              label: l.get('tasks'),
              selected: currentIndex == 1,
              onTap: () => onPickTab(1),
            ),
            _DrawerTile(
              icon: const Icon(Icons.folder_outlined),
              label: l.get('projects'),
              selected: currentIndex == 2,
              onTap: () => onPickTab(2),
            ),
            _DrawerTile(
              icon: const Icon(Icons.calendar_month_outlined),
              label: l.get('calendar'),
              selected: currentIndex == 3,
              onTap: () => onPickTab(3),
            ),
            _DrawerTile(
              icon: const Icon(Icons.bar_chart_outlined),
              label: l.get('statistics'),
              selected: currentIndex == 4,
              onTap: () => onPickTab(4),
            ),

            const Divider(),

            // Tools — separate routes outside the bottom-nav.
            _DrawerSection(label: l.get('tools')),
            _DrawerTile(
              icon: const Icon(Icons.search),
              label: l.get('search'),
              onTap: () {
                Navigator.pop(context);
                context.push('/search');
              },
            ),
            _DrawerTile(
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: l.get('notes'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notes');
              },
            ),
            _DrawerTile(
              icon: const Icon(Icons.view_kanban_outlined),
              label: l.get('kanbanBoard'),
              onTap: () {
                Navigator.pop(context);
                context.push('/kanban');
              },
            ),
            _DrawerTile(
              icon: const Icon(Icons.timer_outlined),
              label: l.get('pomodoro'),
              onTap: () {
                Navigator.pop(context);
                context.push('/pomodoro');
              },
            ),
            _DrawerTile(
              icon: const Icon(Icons.workspaces_outline),
              label: l.get('sharedLists'),
              onTap: () {
                Navigator.pop(context);
                context.push('/shared-lists');
              },
            ),

            if (projectVM.projects.isNotEmpty) ...[
              const Divider(),
              _DrawerSection(label: l.get('projects')),
              ...projectVM.projects.map((p) {
                final count = taskVM.tasks
                    .where((t) => t.projectId == p.id)
                    .length;
                return _DrawerTile(
                  icon: Icon(Icons.circle, color: p.color, size: 20),
                  label: p.name,
                  trailing: _CountChip(count: count),
                  onTap: () {
                    Navigator.pop(context);
                    context
                        .read<HomeFilterIntent>()
                        .setFilter('project:${p.id}');
                    onPickTab(1); // Tasks tab.
                  },
                );
              }),
            ],

            if (categoryVM.categories.isNotEmpty) ...[
              const Divider(),
              _DrawerSection(label: l.get('categories')),
              ...categoryVM.categories.map((c) {
                final count = categoryCounts[c.name] ?? 0;
                return _DrawerTile(
                  icon: Icon(c.icon, color: c.color, size: 20),
                  label: c.name,
                  trailing: _CountChip(count: count),
                  onTap: () {
                    Navigator.pop(context);
                    context
                        .read<HomeFilterIntent>()
                        .setFilter('category:${c.name}');
                    onPickTab(1); // Tasks tab.
                  },
                );
              }),
            ],

            const Divider(),
            _DrawerTile(
              icon: const Icon(Icons.settings_outlined),
              label: l.get('settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            _DrawerTile(
              icon: const Icon(Icons.help_outline),
              label: l.get('helpSupport'),
              onTap: () {
                Navigator.pop(context);
                context.push('/help');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    this.selected = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Inject size + selected/unselected color via IconTheme so Material icons
    // tint correctly without touching call sites. An inner Icon that sets
    // `color` explicitly (e.g. project dots) still wins.
    return ListTile(
      leading: IconTheme.merge(
        data: IconThemeData(
          size: 20,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        child: icon,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: trailing,
      selected: selected,
      onTap: onTap,
      // Disabled-look when there's no handler.
      enabled: onTap != null,
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
