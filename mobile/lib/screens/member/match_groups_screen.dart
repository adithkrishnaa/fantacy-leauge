import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import 'place_bet_screen.dart';
import 'view_bets_screen.dart';

/// The betting groups attached to one match.
class MatchGroupsScreen extends StatefulWidget {
  const MatchGroupsScreen({super.key, required this.match});

  final GameMatch match;

  @override
  State<MatchGroupsScreen> createState() => _MatchGroupsScreenState();
}

class _MatchGroupsScreenState extends State<MatchGroupsScreen> {
  late Future<List<BettingGroup>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = Services.betting.groupsForMatch(widget.match.id);
  }

  void _reload() {
    setState(() {
      _groups = Services.betting.groupsForMatch(widget.match.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = widget.match;

    return Scaffold(
      appBar: AppBar(title: Text(match.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDateTime(match.dateTime),
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (match.clubName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              match.clubName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusChip(match.status),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: AsyncView<List<BettingGroup>>(
                future: _groups,
                onRetry: _reload,
                isEmpty: (data) => data.isEmpty,
                emptyIcon: Icons.casino_outlined,
                emptyTitle: 'No betting groups',
                emptyMessage:
                    'The manager has not opened any groups for this match.',
                builder: (context, groups) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _GroupCard(
                    group: groups[i],
                    match: match,
                    onChanged: _reload,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.match,
    required this.onChanged,
  });

  final BettingGroup group;
  final GameMatch match;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The backend rejects bets unless both the group and the match are Active.
    final canBet = group.isActive && match.isActive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.betType,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(group.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Metric(
                  label: 'Entry',
                  value: formatCredits(group.betAmount),
                ),
                _Metric(
                  label: 'Pot',
                  value: formatCredits(group.totalBetAmount),
                ),
                _Metric(
                  label: 'Prize split',
                  value: '${group.winnerShare1.toStringAsFixed(0)}/'
                      '${group.winnerShare2.toStringAsFixed(0)}/'
                      '${group.winnerShare3.toStringAsFixed(0)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewBetsScreen(group: group),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('View bets'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canBet
                        ? () async {
                            final placed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => PlaceBetScreen(
                                  group: group,
                                  match: match,
                                ),
                              ),
                            );
                            if (placed == true) onChanged();
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Place bet'),
                  ),
                ),
              ],
            ),
            if (!canBet) ...[
              const SizedBox(height: 8),
              Text(
                match.isActive
                    ? 'This group is not accepting bets.'
                    : 'Betting opens when the match is active.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
