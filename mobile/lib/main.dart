import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'models/user.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/member/member_dashboard.dart';
import 'state/auth_state.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FantasyLeagueApp());
}

class FantasyLeagueApp extends StatelessWidget {
  const FantasyLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState()..restore(),
      child: MaterialApp(
        title: 'Fantasy League 7',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const RootGate(),
      ),
    );
  }
}

/// Chooses the screen for the current session: splash while the stored token
/// is verified, login when signed out, then the dashboard for the user's role.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        switch (auth.role) {
          case UserRole.admin:
            return const AdminDashboard();
          case UserRole.manager:
            return const ManagerDashboard();
          case UserRole.member:
            return const MemberDashboard();
          case UserRole.unknown:
            return const _UnknownRoleScreen();
        }
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Defensive fallback: the backend only issues Admin/Manager/Member, so this
/// means the account is in a state the app does not understand.
class _UnknownRoleScreen extends StatelessWidget {
  const _UnknownRoleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessageView(
        icon: Icons.help_outline,
        title: 'Unrecognised account type',
        message: 'This account has a role the app does not support. '
            'Please contact support.',
        onRetry: () => context.read<AuthState>().logout(),
      ),
    );
  }
}
