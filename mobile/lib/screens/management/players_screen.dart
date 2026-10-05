import 'package:flutter/material.dart';

import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Edits the two squads stored in the match's `Team1Players` / `Team2Players`
/// JSON columns. Slots are numbered from 1 and sent as a `slot -> name` map.
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key, required this.match});

  final GameMatch match;

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late List<TextEditingController> _team1;
  late List<TextEditingController> _team2;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _team1 = _controllersFrom(widget.match.team1Players);
    _team2 = _controllersFrom(widget.match.team2Players);
  }

  List<TextEditingController> _controllersFrom(Map<String, String> players) {
    if (players.isEmpty) {
      // Start with a few blank rows so the screen is usable straight away.
      return List.generate(3, (_) => TextEditingController());
    }
    // Sort by numeric slot where possible so the order is stable.
    final entries = players.entries.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a.key);
        final bi = int.tryParse(b.key);
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.key.compareTo(b.key);
      });
    return entries.map((e) => TextEditingController(text: e.value)).toList();
  }

  @override
  void dispose() {
    for (final c in [..._team1, ..._team2]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _toMap(List<TextEditingController> controllers) {
    final map = <String, String>{};
    var slot = 1;
    for (final c in controllers) {
      final name = c.text.trim();
      if (name.isEmpty) continue; // Blank rows are dropped, not saved.
      map['${slot++}'] = name;
    }
    return map;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Services.matches.updatePlayers(
        widget.match.id,
        team1Players: _toMap(_team1),
        team2Players: _toMap(_team2),
      );
      if (!mounted) return;
      showSnack(context, 'Squads saved');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squads'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _TeamSection(
              title: widget.match.team1,
              controllers: _team1,
              onAdd: () =>
                  setState(() => _team1.add(TextEditingController())),
              onRemove: (i) => setState(() {
                _team1.removeAt(i).dispose();
              }),
            ),
            const SizedBox(height: 28),
            _TeamSection(
              title: widget.match.team2,
              controllers: _team2,
              onAdd: () =>
                  setState(() => _team2.add(TextEditingController())),
              onRemove: (i) => setState(() {
                _team2.removeAt(i).dispose();
              }),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save squads'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.title,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add player'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...controllers.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${entry.key + 1}.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Player name',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: controllers.length <= 1
                          ? null
                          : () => onRemove(entry.key),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
