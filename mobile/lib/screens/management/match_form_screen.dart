import 'package:flutter/material.dart';

import '../../models/match.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Create or edit a fixture.
///
/// [clubId] is set only for admins, who must name the club explicitly
/// (`POST /matches/Admin-club/:clubId`); a manager's club is implied.
class MatchFormScreen extends StatefulWidget {
  const MatchFormScreen({super.key, this.match, this.clubId});

  final GameMatch? match;
  final String? clubId;

  bool get isEdit => match != null;

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _team1 =
      TextEditingController(text: widget.match?.team1 ?? '');
  late final TextEditingController _team2 =
      TextEditingController(text: widget.match?.team2 ?? '');

  late DateTime _dateTime =
      widget.match?.dateTime ?? DateTime.now().add(const Duration(hours: 1));
  late String _status = widget.match?.status ?? 'Inactive';
  bool _busy = false;

  static const _statuses = ['Inactive', 'Active', 'Ongoing', 'Completed'];

  @override
  void dispose() {
    _team1.dispose();
    _team2.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.isEdit) {
        await Services.matches.update(
          widget.match!.id,
          team1: _team1.text,
          team2: _team2.text,
          dateTime: _dateTime,
          status: _status,
        );
      } else {
        await Services.matches.create(
          team1: _team1.text,
          team2: _team2.text,
          dateTime: _dateTime,
          status: _status,
          clubId: widget.clubId,
        );
      }
      if (!mounted) return;
      showSnack(context, widget.isEdit ? 'Match updated' : 'Match created');
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
        title: Text(widget.isEdit ? 'Edit match' : 'New match'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _team1,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Team 1'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _team2,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Team 2'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Date & time'),
                    subtitle: Text(formatDateTime(_dateTime)),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: _pickDateTime,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'Inactive'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Members can only bet while the match is Active.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                      : Text(widget.isEdit ? 'Save changes' : 'Create match'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
