import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Create or edit a betting group.
///
/// `Bidding Method` is the only type that requires `minimumIncrement`; the
/// backend rejects the create otherwise.
class GroupFormScreen extends StatefulWidget {
  const GroupFormScreen({super.key, required this.match, this.group});

  final GameMatch match;
  final BettingGroup? group;

  bool get isEdit => group != null;

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  static const _betTypes = ['First Better', 'Multi Better', 'Bidding Method'];
  static const _statuses = ['Inactive', 'Active', 'Completed'];

  final _formKey = GlobalKey<FormState>();

  late String _betType = widget.group?.betType ?? 'First Better';
  late String _status = widget.group?.status ?? 'Inactive';

  late final TextEditingController _betAmount = TextEditingController(
    text: widget.group?.betAmount.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _increment = TextEditingController(
    text: widget.group?.minimumIncrement?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _share1 = TextEditingController(
    text: widget.group?.winnerShare1.toStringAsFixed(0) ?? '50',
  );
  late final TextEditingController _share2 = TextEditingController(
    text: widget.group?.winnerShare2.toStringAsFixed(0) ?? '30',
  );
  late final TextEditingController _share3 = TextEditingController(
    text: widget.group?.winnerShare3.toStringAsFixed(0) ?? '20',
  );

  bool _busy = false;

  bool get _needsIncrement => _betType == 'Bidding Method';

  @override
  void dispose() {
    _betAmount.dispose();
    _increment.dispose();
    _share1.dispose();
    _share2.dispose();
    _share3.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  String? _requiredNumber(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed <= 0) return 'Must be greater than 0';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.isEdit) {
        await Services.betting.updateGroup(
          widget.group!.id,
          betType: _betType,
          betAmount: _num(_betAmount),
          minimumIncrement: _needsIncrement ? _num(_increment) : null,
          winnerShare1: _num(_share1),
          winnerShare2: _num(_share2),
          winnerShare3: _num(_share3),
          status: _status,
        );
      } else {
        await Services.betting.createGroup(
          matchId: widget.match.id,
          betType: _betType,
          betAmount: _num(_betAmount),
          minimumIncrement: _needsIncrement ? _num(_increment) : null,
          winnerShare1: _num(_share1),
          winnerShare2: _num(_share2),
          winnerShare3: _num(_share3),
          status: _status,
        );
      }
      if (!mounted) return;
      showSnack(context, widget.isEdit ? 'Group updated' : 'Group created');
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
    final shareTotal = _num(_share1) + _num(_share2) + _num(_share3);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit group' : 'New betting group'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _betType,
                  decoration: const InputDecoration(labelText: 'Bet type'),
                  items: _betTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _betType = v ?? 'First Better'),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (_betType) {
                    'First Better' =>
                      'Each combination can be claimed by one member only.',
                    'Multi Better' =>
                      'Several members may hold the same combination, but each '
                          'member only once.',
                    _ => 'Members bid upward in steps of the minimum increment.',
                  },
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _betAmount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Entry amount',
                    prefixText: '₹ ',
                  ),
                  validator: _requiredNumber,
                ),
                if (_needsIncrement) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _increment,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum increment',
                      prefixText: '₹ ',
                    ),
                    validator: _needsIncrement ? _requiredNumber : null,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Prize split (%)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _share1,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '1st'),
                        onChanged: (_) => setState(() {}),
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _share2,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '2nd'),
                        onChanged: (_) => setState(() {}),
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _share3,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '3rd'),
                        onChanged: (_) => setState(() {}),
                        validator: _requiredNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${shareTotal.toStringAsFixed(0)}%'
                  '${shareTotal == 100 ? '' : '  — usually adds up to 100'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: shareTotal == 100
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'Inactive'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEdit ? 'Save changes' : 'Create group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
