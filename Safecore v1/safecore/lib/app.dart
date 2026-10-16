import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/config_required_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/main_shell.dart';
import 'repositories/repositories.dart';
import 'routes/app_routes.dart';
import 'services/session_controller.dart';
import 'shared/widgets/async_states.dart';

class SafeCoreApp extends StatelessWidget {
  const SafeCoreApp({super.key, required this.configured, this.initError});

  final bool configured;
  final Object? initError;

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeCore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRoutes.onGenerateRoute,
      // O SessionScope envolve o Navigator: todas as rotas acessam o perfil.
      builder: (context, child) => SessionScope(controller: appSession, child: child!),
      home: configured ? const AuthGate() : ConfigRequiredScreen(error: initError),
    );
  }
}

/// Decide entre Login e o aplicativo conforme a sessão do Supabase Auth.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _session = appSession;
  late final StreamSubscription<AuthState> _sub;
  bool _signedIn = false;
  bool _loadingProfile = false;
  Object? _profileError;

  @override
  void initState() {
    super.initState();
    _signedIn = Repos.auth.currentUser != null;
    if (_signedIn) _loadProfile();
    _sub = Repos.auth.authStateChanges.listen(_onAuthChange, onError: (_) {});
  }

  void _onAuthChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.passwordRecovery:
        SafeCoreApp.navigatorKey.currentState?.pushNamed(AppRoutes.resetPassword);
      case AuthChangeEvent.signedIn:
        if (!_signedIn) {
          setState(() => _signedIn = true);
          _loadProfile();
        }
      case AuthChangeEvent.signedOut:
        _session.clear();
        SafeCoreApp.navigatorKey.currentState?.popUntil((r) => r.isFirst);
        setState(() => _signedIn = false);
      case AuthChangeEvent.userUpdated:
        if (_signedIn) _session.refreshProfile().catchError((_) {});
      default:
        break;
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      await _session.load();
    } catch (e) {
      _profileError = e;
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return const LoginScreen();
    if (_loadingProfile) return const Scaffold(body: LoadingView(message: 'Carregando...'));
    if (_profileError != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: ErrorView(error: _profileError!, onRetry: _loadProfile)),
              TextButton(onPressed: Repos.auth.signOut, child: const Text('Sair da conta')),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
    return const MainShell();
  }
}
