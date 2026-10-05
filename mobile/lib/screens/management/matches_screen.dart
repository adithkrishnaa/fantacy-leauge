import 'package:flutter/material.dart';

import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import 'manage_match_screen.dart';
import 'match_form_screen.dart';

/// Fixture list for managers (own club) and admins (a chosen club).
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, this.clubId, this.title});

  /// Set by admins to scope to one club; null for a manager's own club.
  final String? clubId;
  final String? title;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late Future<List<GameMatch>> _matches;

  @override
  void initState() {
    super.initState();
    _matches = _load();
  }

  Future<List<GameMatch>> _load() async {
    final list = widget.clubId == null
        ? await Services.matches.list()
        : await Services.matches.byClub(widget.clubId!);
    list.sort((a, b) {
      final ad = a.dateTime;
      final bd = b.dateTime;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return list;
  }

  void _reload() => setState(() => _matches = _load());

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MatchFormScreen(clubId: widget.clubId),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _edit(GameMatch match) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MatchFormScreen(match: match)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(GameMatch match) async {
    final ok = await confirm(
      context,
      title: 'Delete match',
      message: 'Delete ${match.title}? Betting groups and bets attached to '
          'this match may be removed too. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Services.matches.remove(match.id);
      if (!mounted) return;
      showSnack(context, 'Match deleted');
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Matches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New match'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: AsyncView<List<GameMatch>>(
          future: _matches,
          onRetry: _reload,
          isEmpty: (data) => data.isEmpty,
          emptyIcon: Icons.event_busy_outlined,
          emptyTitle: 'No matches',
          emptyMessage: 'Create a match to open betting groups.',
          builder: (context, matches) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final match = matches[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusChip(match.status),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _edit(match);
                              if (value == 'delete') _delete(match);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        formatDateTime(match.dateTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ManageMatchScreen(match: match),
                              ),
                            );
                            _reload();
                          },
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Manage'),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
