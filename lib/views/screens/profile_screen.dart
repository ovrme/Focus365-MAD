import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_localizations.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/label_viewmodel.dart';
import '../../viewmodels/note_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/shared_list_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../viewmodels/user_profile_viewmodel.dart';
import '../../services/streak_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authVM = context.watch<AuthViewModel>();
    final taskVM = context.watch<TaskViewModel>();
    final l = AppLocalizations.of(context);
    final user = authVM.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage:
                user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            child: user?.photoUrl == null
                ? Text(
                    user != null && user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? l.get('guestUser'),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            user?.email ?? l.get('notSignedIn'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showEditProfileDialog(context),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(l.get('editProfile')),
            ),
          ],
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _ProfileStat(
                  label: l.get('total'),
                  value: '${taskVM.tasks.length}',
                  theme: theme),
              _ProfileStat(
                  label: l.get('done'),
                  value: '${taskVM.completedTasks.length}',
                  theme: theme),
              _ProfileStat(
                  label: l.get('active'),
                  value: '${taskVM.activeTasks.length}',
                  theme: theme),
            ],
          ),
          const SizedBox(height: 16),

          // Streak & Productivity
          FutureBuilder<List<int>>(
            future: Future.wait([
              StreakService().getCurrentStreak(),
              StreakService().getBestStreak(),
              StreakService().getProductivityScore(taskVM.tasks),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final currentStreak = snapshot.data![0];
              final bestStreak = snapshot.data![1];
              final score = snapshot.data![2];
              return Row(
                children: [
                  _ProfileStat(
                    label: l.get('streak'),
                    value: '$currentStreak',
                    theme: theme,
                    icon: Icons.local_fire_department,
                    iconColor: Colors.deepOrange,
                  ),
                  _ProfileStat(
                    label: l.get('bestStreak'),
                    value: '$bestStreak',
                    theme: theme,
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                  ),
                  _ProfileStat(
                    label: l.get('score'),
                    value: '$score',
                    theme: theme,
                    icon: Icons.speed,
                    iconColor: score >= 70
                        ? Colors.green
                        : score >= 40
                            ? Colors.orange
                            : Colors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Member since
          if (user != null)
            Card(
              child: ListTile(
                leading: Icon(Icons.calendar_today,
                    color: theme.colorScheme.primary),
                title: Text(l.get('memberSince')),
                subtitle: Text(
                  '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Actions
          if (user != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.get('signOut')),
                      content: Text(l.get('signOutConfirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l.get('cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l.get('signOut')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    // Clear all per-user state before flipping auth so the
                    // next account can't see the previous user's data.
                    context.read<TaskViewModel>().reset();
                    context.read<ProjectViewModel>().reset();
                    context.read<LabelViewModel>().reset();
                    context.read<CategoryViewModel>().reset();
                    context.read<SharedListViewModel>().reset();
                    context.read<UserProfileViewModel>().reset();
                    context.read<NoteViewModel>().reset();
                    await authVM.signOut();
                    if (context.mounted) context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(l.get('signOut')),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: Text(l.get('signIn')),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.get('signInToSync'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authVM = context.read<AuthViewModel>();
    final nameCtrl =
        TextEditingController(text: authVM.user?.displayName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('editProfile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l.get('fullName'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                await authVM.updateDisplayName(name);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(l.get('save')),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final IconData? icon;
  final Color? iconColor;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.theme,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(height: 4),
              ],
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
