import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../member/view_bets_screen.dart';
import 'group_form_screen.dart';
import 'players_screen.dart';
import 'result_form_screen.dart';

/// Everything a manager or admin does to one fixture: betting groups, squads,
/// the scorecard, and final settlement.
class ManageMatchScreen extends StatefulWidget {
  const ManageMatchScreen({super.key, required this.match});

  final GameMatch match;

  @override
  State<ManageMatchScreen> createState() => _ManageMatchScreenState();
}

class _ManageMatchScreenState extends State<ManageMatchScreen> {
  late GameMatch _match = widget.match;
  late Future<List<BettingGroup>> _groups;
  bool _approving = false;

  @override
  void initState() {
    super.initState();
    _groups = Services.betting.groupsForMatch(_match.id);
  }

  Future<void> _reload() async {
    try {
      _match = await Services.matches.byId(_match.id);
    } on ApiException {
      // Keep the match we already have; the group list still refreshes.
    }
    if (!mounted) return;
    setState(() {
      _groups = Services.betting.groupsForMatch(_match.id);
    });
  }

  Future<void> _addGroup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GroupFormScreen(match: _match)),
    );
    if (created == true) _reload();
  }

  Future<void> _editGroup(BettingGroup group) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GroupFormScreen(match: _match, group: group),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteGroup(BettingGroup group) async {
    final ok = await confirm(
      context,
      title: 'Delete group',
      message: 'Delete this ${group.betType} group? Bets placed in it may be '
          'removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Services.betting.deleteGroup(group.id);
      if (!mounted) return;
      showSnack(context, 'Group deleted');
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _approveCredits() async {
    final ok = await confirm(
      context,
      title: 'Settle match',
      message: 'This calculates winners and pays out credits for '
          '${_match.title}. It cannot be undone.',
      confirmLabel: 'Settle & pay out',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _approving = true);
    try {
      await Services.matches.approveCredits(_match.id);
      if (!mounted) return;
      showSnack(context, 'Winners paid out');
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_match.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGroup,
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDateTime(_match.dateTime)),
                          const SizedBox(height: 4),
                          Text(
                            _match.prizeShareStatus
                                ? 'Prizes have been paid out'
                                : 'Not settled yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(_match.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ActionTile(
              icon: Icons.groups_outlined,
              title: 'Squads',
              subtitle: '${_match.team1Players.length} + '
                  '${_match.team2Players.length} players',
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PlayersScreen(match: _match),
                  ),
                );
                if (saved == true) _reload();
              },
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.scoreboard_outlined,
              title: _match.resultId == null ? 'Add result' : 'Edit result',
              subtitle: 'Per-over scores for both teams',
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ResultFormScreen(match: _match),
                  ),
                );
                if (saved == true) _reload();
              },
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Settle match',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scores the bets, picks winners and credits their '
                      'wallets. Add the result first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_approving || _match.prizeShareStatus)
                            ? null
                            : _approveCredits,
                        icon: _approving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payments_outlined, size: 18),
                        label: Text(
                          _match.prizeShareStatus
                              ? 'Already settled'
                              : 'Approve credits',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Betting groups',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AsyncViewInline<List<BettingGroup>>(
              future: _groups,
              onRetry: _reload,
              emptyTitle: 'No groups yet',
              emptyMessage: 'Add a group so members can start betting.',
              isEmpty: (d) => d.isEmpty,
              builder: (context, groups) => Column(
                children: groups
                    .map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GroupRow(
                            group: g,
                            onEdit: () => _editGroup(g),
                            onDelete: () => _deleteGroup(g),
                            onViewBets: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ViewBetsScreen(group: g),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [AsyncView] renders full-screen states; inside a scrolling page we want the
/// same four states laid out inline instead.
class AsyncViewInline<T> extends StatelessWidget {
  const AsyncViewInline({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.isEmpty,
  });

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final bool Function(T)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(error is ApiException ? error.message : '$error'),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        final data = snapshot.data as T;
        if (isEmpty?.call(data) ?? false) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    emptyTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (emptyMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(emptyMessage!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          );
        }
        return builder(context, data);
      },
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onViewBets,
  });

  final BettingGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewBets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.betType,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(group.status),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'bets') onViewBets();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'bets', child: Text('View bets')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Entry ${formatCredits(group.betAmount)}  ·  '
              'Pot ${formatCredits(group.totalBetAmount)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
