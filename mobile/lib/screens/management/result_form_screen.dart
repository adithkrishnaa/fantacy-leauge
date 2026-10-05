import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/match.dart';

import '../../services/services.dart';
import '../../widgets/common.dart';

/// Scorecard entry.
///
/// `resultPolicy.normalizeResultScores` requires exactly seven non-negative
/// integers per team — the same seven slots the bet symbols refer to
/// (`1`-`7` for team 1, `A`-`G` for team 2), so each field is labelled with
/// its symbol.
class ResultFormScreen extends StatefulWidget {
  const ResultFormScreen({super.key, required this.match});

  final GameMatch match;

  @override
  State<ResultFormScreen> createState() => _ResultFormScreenState();
}

class _ResultFormScreenState extends State<ResultFormScreen> {
  static const int _slots = 7;
  static const List<String> _team1Symbols = ['1', '2', '3', '4', '5', '6', '7'];
  static const List<String> _team2Symbols = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _team1 =
      List.generate(_slots, (_) => TextEditingController());
  final List<TextEditingController> _team2 =
      List.generate(_slots, (_) => TextEditingController());

  bool _loading = false;
  bool _busy = false;
  String? _resultId;

  @override
  void initState() {
    super.initState();
    _resultId = widget.match.resultId;
    if (_resultId != null && _resultId!.isNotEmpty) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final result = await Services.matches.result(_resultId!);
      _fill(_team1, result.team1Scores);
      _fill(_team2, result.team2Scores);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(List<TextEditingController> controllers, List<int> scores) {
    for (var i = 0; i < controllers.length && i < scores.length; i++) {
      controllers[i].text = '${scores[i]}';
    }
  }

  List<int> _values(List<TextEditingController> controllers) =>
      controllers.map((c) => int.tryParse(c.text.trim()) ?? 0).toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final team1 = _values(_team1);
      final team2 = _values(_team2);

      if (_resultId != null && _resultId!.isNotEmpty) {
        await Services.matches.updateResult(
          _resultId!,
          matchId: widget.match.id,
          team1Scores: team1,
          team2Scores: team2,
        );
      } else {
        final created = await Services.matches.addResult(
          matchId: widget.match.id,
          team1Scores: team1,
          team2Scores: team2,
        );
        _resultId = created.id;
      }
      if (!mounted) return;
      showSnack(context, 'Result saved');
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = _resultId != null && _resultId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit result' : 'Add result')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Enter seven scores for each team. These are the slots members '
                'bet on.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _ScoreSection(
                title: widget.match.team1,
                symbols: _team1Symbols,
                controllers: _team1,
              ),
              const SizedBox(height: 24),
              _ScoreSection(
                title: widget.match.team2,
                symbols: _team2Symbols,
                controllers: _team2,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Update result' : 'Save result'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSection extends StatelessWidget {
  const _ScoreSection({
    required this.title,
    required this.symbols,
    required this.controllers,
  });

  final String title;
  final List<String> symbols;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...List.generate(controllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    symbols[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers[i],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Score',
                      isDense: true,
                    ),
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null) return 'Required';
                      if (value < 0) return 'Must be 0 or more';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
