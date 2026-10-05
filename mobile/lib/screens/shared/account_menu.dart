import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import 'change_password_screen.dart';

/// App-bar overflow menu shared by all three dashboards.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) async {
        switch (value) {
          case 'password':
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          case 'logout':
            final ok = await confirm(
              context,
              title: 'Sign out',
              message: 'You will need to sign in again to place bets.',
              confirmLabel: 'Sign out',
            );
            if (ok && context.mounted) {
              await context.read<AuthState>().logout();
            }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'password',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Change password'),
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
