import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../shared/account_menu.dart';
import 'match_groups_screen.dart';
import 'my_bets_screen.dart';
import 'referral_screen.dart';
import 'wallet_screen.dart';

/// Home for a `Member`: wallet balance, their club's fixtures, and shortcuts.
class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  late Future<List<GameMatch>> _matches;

  @override
  void initState() {
    super.initState();
    _matches = _load();
  }

  Future<List<GameMatch>> _load() async {
    final user = context.read<AuthState>().user;
    final clubId = user?.memberOfId;
    // Members only see fixtures for the club an admin assigned them to.
    if (clubId == null || clubId.isEmpty) return const [];
    final matches = await Services.matches.byClub(clubId);
    matches.sort((a, b) {
      final ad = a.dateTime;
      final bd = b.dateTime;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return matches;
  }

  Future<void> _refresh() async {
    await context.read<AuthState>().refresh();
    setState(() => _matches = _load());
    await _matches;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fantasy League 7'),
        actions: const [AccountMenu()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Hi ${user?.firstName ?? ''}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              user?.memberOfName ?? 'No club assigned yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _BalanceCard(credits: auth.credits),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ActionTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'My bets',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyBetsScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet history',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.card_giftcard_outlined,
              title: 'Refer & earn',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReferralScreen()),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Matches',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (!(user?.hasClub ?? false))
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined, size: 36),
                      SizedBox(height: 12),
                      Text(
                        'Waiting for club assignment',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'An admin needs to add you to a club before you can '
                        'see matches and place bets.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 420,
                child: AsyncView<List<GameMatch>>(
                  future: _matches,
                  onRetry: _refresh,
                  isEmpty: (data) => data.isEmpty,
                  emptyIcon: Icons.event_busy_outlined,
                  emptyTitle: 'No matches yet',
                  emptyMessage:
                      'Your club has not scheduled any matches so far.',
                  builder: (context, matches) => ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _MatchCard(
                      match: matches[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchGroupsScreen(match: matches[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.credits});

  final double credits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: scheme.onPrimaryContainer,
              size: 32,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available credits',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCredits(credits),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.onTap});

  final GameMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(match.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDateTime(match.dateTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
