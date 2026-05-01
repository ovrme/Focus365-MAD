import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/user_session_bootstrap.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/shared_list_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../viewmodels/user_profile_viewmodel.dart';
import '../../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _initialize();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final authVM = context.read<AuthViewModel>();
    await authVM.checkAuthState();
    if (!mounted) return;

    if (authVM.isAuthenticated) {
      final userId = authVM.user?.uid;
      if (userId == null) {
        // User object is invalid, redirect to login
        context.go('/login');
        return;
      }

      await bootstrapUserSession(context, userId);
      if (!mounted) return;

      // One-time cross-VM wiring (must only run once per app start, not on
      // every login — listeners would otherwise pile up). Fans shared-list
      // member changes into TaskViewModel and UserProfileViewModel.
      final sharedListVM = context.read<SharedListViewModel>();
      final taskVM = context.read<TaskViewModel>();
      final profileVM = context.read<UserProfileViewModel>();
      sharedListVM.addListener(() {
        taskVM.setSharedListIds(sharedListVM.memberListIds);
        final allMemberIds = <String>{};
        for (final l in sharedListVM.lists) {
          allMemberIds.addAll(l.memberIds);
        }
        profileVM.ensureLoaded(allMemberIds);
      });

      if (!mounted) return;

      final settingsVM = context.read<SettingsViewModel>();
      if (!settingsVM.onboardingSeen) {
        context.go('/onboarding');
      } else {
        // Check biometric auth if enabled
        if (settingsVM.biometricEnabled) {
          final authenticated = await BiometricService().authenticate();
          if (!mounted) return;
          if (!authenticated) {
            // Show retry option instead of leaving user stuck
            _showBiometricRetryDialog();
            return;
          }
        }
        if (mounted) context.go('/home');
      }
    } else {
      final settingsVM = context.read<SettingsViewModel>();
      if (!settingsVM.onboardingSeen) {
        context.go('/onboarding');
      } else {
        context.go('/login');
      }
    }
  }

  void _showBiometricRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text('Biometric authentication failed. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Disable biometric and proceed
              context.read<SettingsViewModel>().setBiometricEnabled(false);
              context.go('/home');
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authenticated = await BiometricService().authenticate();
              if (!mounted) return;
              if (authenticated) {
                context.go('/home');
              } else {
                _showBiometricRetryDialog();
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Image.asset(
                    'assets/images/logos/logo.png',
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      Text(
                        'Focus24',
                        style:
                            theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Focus every day, all 365',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
