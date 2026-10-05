import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/club.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../management/matches_screen.dart';
import '../management/members_screen.dart';
import '../shared/account_menu.dart';
import 'club_form_screen.dart';

/// Home for an `Admin`: every club, and a way into each club's matches and
/// members using the same management screens managers use.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<List<Club>> _clubs;

  @override
  void initState() {
    super.initState();
    _clubs = Services.clubs.list();
  }

  void _reload() => setState(() => _clubs = Services.clubs.list());

  Future<void> _createClub() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ClubFormScreen()),
    );
    if (created == true) _reload();
  }

  Future<void> _editClub(Club club) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClubFormScreen(club: club)),
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteClub(Club club) async {
    final ok = await confirm(
      context,
      title: 'Delete club',
      message: 'Delete ${club.clubName}? Its matches, groups and member links '
          'may be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Services.clubs.remove(club.id);
      if (!mounted) return;
      showSnack(context, 'Club deleted');
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: const [AccountMenu()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClub,
        icon: const Icon(Icons.add),
        label: const Text('New club'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              user?.fullName ?? 'Administrator',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Platform administrator',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            ActionTile(
              icon: Icons.sports_cricket,
              title: 'All matches',
              subtitle: 'Every fixture across all clubs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MatchesScreen(title: 'All matches'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.people_outline,
              title: 'All members',
              subtitle: 'Roster and credits across clubs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MembersScreen(title: 'All members'),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Clubs',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Club>>(
              future: _clubs,
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
                          Text(
                            error is ApiException ? error.message : '$error',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _reload,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final clubs = snapshot.data ?? const <Club>[];
                if (clubs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No clubs yet. Create one to get started.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  children: clubs
                      .map((club) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ClubCard(
                              club: club,
                              onEdit: () => _editClub(club),
                              onDelete: () => _deleteClub(club),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.club,
    required this.onEdit,
    required this.onDelete,
  });

  final Club club;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                    club.clubName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Text(
              '${club.managerName} · ${club.managerPhone}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manager ${club.managerShare.toStringAsFixed(0)}% · '
              'Admin ${club.adminShare.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchesScreen(
                            clubId: club.id,
                            title: club.clubName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.sports_cricket, size: 18),
                      label: const Text('Matches'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MembersScreen(
                            clubId: club.id,
                            title: club.clubName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('Members'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
