import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../models/user.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../management/matches_screen.dart';
import '../management/members_screen.dart';
import '../member/wallet_screen.dart';
import '../shared/account_menu.dart';

/// Home for a `Manager`: their club's fixtures and roster.
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  late Future<_ManagerSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<_ManagerSummary> _load() async {
    // Either call can fail independently (e.g. a manager with no club yet), so
    // neither is allowed to sink the whole dashboard.
    List<GameMatch> matches = const [];
    List<AppUser> members = const [];
    try {
      matches = await Services.matches.list();
    } on ApiException {
      matches = const [];
    }
    try {
      members = await Services.clubs.members();
    } on ApiException {
      members = const [];
    }
    return _ManagerSummary(matches: matches, members: members);
  }

  Future<void> _refresh() async {
    await context.read<AuthState>().refresh();
    setState(() => _summary = _load());
    await _summary;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager'),
        actions: const [AccountMenu()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              user?.fullName ?? 'Manager',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              user?.memberOfName ?? 'Club manager',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<_ManagerSummary>(
              future: _summary,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final activeMatches =
                    data?.matches.where((m) => m.isActive).length ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Matches',
                        value: '${data?.matches.length ?? '—'}',
                        icon: Icons.sports_cricket,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Active now',
                        value: '$activeMatches',
                        icon: Icons.play_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Members',
                        value: '${data?.members.length ?? '—'}',
                        icon: Icons.people_outline,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ActionTile(
              icon: Icons.sports_cricket,
              title: 'Matches',
              subtitle: 'Create fixtures, groups, squads and results',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MatchesScreen()),
                );
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.people_outline,
              title: 'Members',
              subtitle: 'Roster and credits',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MembersScreen()),
                );
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'My wallet history',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerSummary {
  const _ManagerSummary({required this.matches, required this.members});

  final List<GameMatch> matches;
  final List<AppUser> members;
}
