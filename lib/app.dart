import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'routes/router.dart';
import 'theme/app_theme.dart';
import 'utils/app_localizations.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'services/connectivity_service.dart';

class Focus24App extends StatefulWidget {
  const Focus24App({super.key});

  @override
  State<Focus24App> createState() => _Focus24AppState();
}

class _Focus24AppState extends State<Focus24App> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final authVM = context.read<AuthViewModel>();

    // Create router once
    _router ??= createAppRouter(authVM);

    return MaterialApp.router(
      title: 'Focus24',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(settingsVM.locale),
      darkTheme: AppTheme.darkTheme(settingsVM.locale),
      themeMode: settingsVM.themeMode,
      locale: settingsVM.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('km'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) {
        return _ConnectivityWrapper(child: child!);
      },
    );
  }
}

class _ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  const _ConnectivityWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();

    return Column(
      children: [
        Expanded(child: child),
        if (!connectivity.isOnline)
          Material(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade800,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).get('offlineMode'),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
