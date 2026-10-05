import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bet.dart';
import '../../models/group.dart';
import '../../models/match.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';

/// Builds one or more three-symbol combinations and submits them.
///
/// Mirrors the server-side rules in `betPolicy.js` and `placeBet` so the user
/// finds out about a clash before spending a round trip:
///   * combination must be 3 symbols from `[1-7A-G]`
///   * `First Better` — a combination may be claimed by only one member
///   * `Multi Better` — a member may not repeat their own combination
///   * the stake per bet is fixed at the group's `betAmount`
class PlaceBetScreen extends StatefulWidget {
  const PlaceBetScreen({super.key, required this.group, required this.match});

  final BettingGroup group;
  final GameMatch match;

  @override
  State<PlaceBetScreen> createState() => _PlaceBetScreenState();
}

class _PlaceBetScreenState extends State<PlaceBetScreen> {
  final List<String?> _slots = List<String?>.filled(kCombinationLength, null);
  final List<String> _slip = [];

  int _activeSlot = 0;
  bool _submitting = true;
  List<Bet> _existing = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _submitting = true;
      _loadError = null;
    });
    try {
      _existing = await Services.betting.betsForGroup(widget.group.id);
    } on ApiException catch (e) {
      // Not fatal — the server re-validates on submit. Warn and continue.
      _loadError = e.message;
      _existing = const [];
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _current => _slots.map((s) => s ?? '').join();
  bool get _isComplete => _slots.every((s) => s != null);

  String _canonical(String value) => (value.split('')..sort()).join();

  /// Combinations that are unavailable to this member, canonicalised the same
  /// way the backend compares them.
  Set<String> get _blocked {
    final userId = context.read<AuthState>().user?.id;
    final blocked = <String>{};

    if (widget.group.isFirstBetter) {
      // Any member holding it locks it out for everyone.
      for (final bet in _existing) {
        blocked.add(bet.canonical);
      }
      for (final combo in widget.group.selectedCombinations) {
        blocked.add(_canonical(combo));
      }
    } else {
      // Multi Better: only this member's own combinations are blocked.
      for (final bet in _existing.where((b) => b.betterId == userId)) {
        blocked.add(bet.canonical);
      }
    }
    // Anything already queued this session.
    for (final combo in _slip) {
      blocked.add(_canonical(combo));
    }
    return blocked;
  }

  String? get _validationError {
    if (!_isComplete) return null;
    final canonical = _canonical(_current);
    if (_blocked.contains(canonical)) {
      return widget.group.isFirstBetter
          ? 'That combination is already taken.'
          : 'You have already bet on that combination.';
    }
    return null;
  }

  void _tapSymbol(String symbol) {
    setState(() {
      _slots[_activeSlot] = symbol;
      final next = _slots.indexWhere((s) => s == null);
      _activeSlot = next == -1 ? _activeSlot : next;
    });
  }

  void _clear() {
    setState(() {
      for (var i = 0; i < _slots.length; i++) {
        _slots[i] = null;
      }
      _activeSlot = 0;
    });
  }

  void _addToSlip() {
    if (!_isComplete || _validationError != null) return;
    setState(() {
      _slip.add(_current);
      for (var i = 0; i < _slots.length; i++) {
        _slots[i] = null;
      }
      _activeSlot = 0;
    });
  }

  double get _totalCost => widget.group.betAmount * _slip.length;

  Future<void> _submit() async {
    final auth = context.read<AuthState>();
    if (_slip.isEmpty) return;

    if (auth.credits < _totalCost) {
      showSnack(
        context,
        'Insufficient credits. You need ${formatCredits(_totalCost)}.',
        isError: true,
      );
      return;
    }

    final ok = await confirm(
      context,
      title: _slip.length == 1 ? 'Place bet' : 'Place ${_slip.length} bets',
      message: '${_slip.join(', ')}\n\n'
          'Total stake ${formatCredits(_totalCost)} will be debited from '
          'your credits.',
      confirmLabel: 'Place',
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      if (_slip.length == 1) {
        await Services.betting.placeBet(
          matchId: widget.match.id,
          groupId: widget.group.id,
          betAmount: widget.group.betAmount,
          combination: _slip.first,
        );
      } else {
        await Services.betting.placeMultipleBets(
          matchId: widget.match.id,
          groupId: widget.group.id,
          betAmount: widget.group.betAmount,
          combinations: List<String>.from(_slip),
        );
      }
      await auth.refresh();
      if (!mounted) return;
      showSnack(context, 'Bet placed');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
      // The clash may have happened between load and submit — resync.
      await _loadExisting();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credits = context.watch<AuthState>().credits;
    final blocked = _blocked;
    final error = _validationError;

    return Scaffold(
      appBar: AppBar(title: const Text('Place bet')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Could not load existing bets ($_loadError). '
                            'Taken combinations may not be shown.',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Your credits',
                          value: formatCredits(credits),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: 'Stake per bet',
                          value: formatCredits(widget.group.betAmount),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your combination',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick $kCombinationLength symbols. Order does not matter.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SlotRow(
                    slots: _slots,
                    activeSlot: _activeSlot,
                    onTapSlot: (i) => setState(() => _activeSlot = i),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _SymbolGrid(
                    onTap: _tapSymbol,
                    selectedSlot: _slots[_activeSlot],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _current.isEmpty ? null : _clear,
                          icon: const Icon(Icons.backspace_outlined, size: 18),
                          label: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_isComplete && error == null)
                              ? _addToSlip
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                  if (_slip.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Bet slip (${_slip.length})',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._slip.asMap().entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: CombinationChips(entry.value),
                              subtitle:
                                  Text(formatCredits(widget.group.betAmount)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                  () => _slip.removeAt(entry.key),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                  if (blocked.isNotEmpty && widget.group.isFirstBetter) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Already taken (${blocked.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: blocked
                          .take(40)
                          .map((c) => Chip(
                                label: Text(c),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            _SubmitBar(
              count: _slip.length,
              total: _totalCost,
              busy: _submitting,
              onSubmit: _slip.isEmpty || _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slots,
    required this.activeSlot,
    required this.onTapSlot,
  });

  final List<String?> slots;
  final int activeSlot;
  final ValueChanged<int> onTapSlot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(slots.length, (i) {
        final active = i == activeSlot;
        final value = slots[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == slots.length - 1 ? 0 : 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTapSlot(i),
              child: Container(
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == null
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Text(
                  value ?? '—',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: value == null
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SymbolGrid extends StatelessWidget {
  const _SymbolGrid({required this.onTap, required this.selectedSlot});

  final ValueChanged<String> onTap;
  final String? selectedSlot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kCombinationSymbols.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final symbol = kCombinationSymbols[i];
        final selected = symbol == selectedSlot;
        return Material(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(symbol),
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.count,
    required this.total,
    required this.busy,
    required this.onSubmit,
  });

  final int count;
  final double total;
  final bool busy;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 1 ? '1 bet' : '$count bets',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatCredits(total),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}
