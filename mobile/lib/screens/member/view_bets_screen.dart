import 'package:flutter/material.dart';

import '../../models/bet.dart';
import '../../models/group.dart';
import '../../models/winners.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Every bet placed in a group, plus the winners once the match is settled.
class ViewBetsScreen extends StatefulWidget {
  const ViewBetsScreen({super.key, required this.group});

  final BettingGroup group;

  @override
  State<ViewBetsScreen> createState() => _ViewBetsScreenState();
}

class _ViewBetsScreenState extends State<ViewBetsScreen> {
  late Future<_GroupSheet> _sheet;

  @override
  void initState() {
    super.initState();
    _sheet = _load();
  }

  Future<_GroupSheet> _load() async {
    final bets = await Services.betting.betsForGroup(widget.group.id);
    // Winners only exist after `approveCredits` has run; a null body is normal.
    GroupWinners? winners;
    try {
      winners = await Services.betting.winnersForGroup(widget.group.id);
    } on ApiException {
      winners = null;
    }
    return _GroupSheet(bets: bets, winners: winners);
  }

  void _reload() => setState(() => _sheet = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Betting sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: AsyncView<_GroupSheet>(
        future: _sheet,
        onRetry: _reload,
        isEmpty: (data) => data.bets.isEmpty && (data.winners?.isEmpty ?? true),
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'No bets yet',
        emptyMessage: 'Be the first to place a bet in this group.',
        builder: (context, sheet) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (sheet.winners != null && !sheet.winners!.isEmpty) ...[
              _WinnersCard(winners: sheet.winners!),
              const SizedBox(height: 20),
            ],
            Text(
              'All bets (${sheet.bets.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...sheet.bets.map((bet) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: CombinationChips(bet.combination, compact: true),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(bet.betterName ?? 'Member'),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCredits(bet.betAmount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (bet.score != 0)
                          Text(
                            'Score ${bet.score.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _GroupSheet {
  const _GroupSheet({required this.bets, this.winners});

  final List<Bet> bets;
  final GroupWinners? winners;
}

class _WinnersCard extends StatelessWidget {
  const _WinnersCard({required this.winners});

  final GroupWinners winners;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Color(0xFFF5A524)),
                const SizedBox(width: 8),
                Text(
                  'Winners',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _tier(context, '1st', winners.first),
            _tier(context, '2nd', winners.second),
            _tier(context, '3rd', winners.third),
          ],
        ),
      ),
    );
  }

  Widget _tier(BuildContext context, String label, List<WinnerEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(child: Text(e.fullName)),
                  if (e.combination.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        e.combination,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (e.amount > 0)
                    Text(
                      formatCredits(e.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
