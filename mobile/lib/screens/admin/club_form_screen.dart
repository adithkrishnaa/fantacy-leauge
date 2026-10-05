import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/club.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Create or edit a club. Creating one also provisions the manager account.
class ClubFormScreen extends StatefulWidget {
  const ClubFormScreen({super.key, this.club});

  final Club? club;

  bool get isEdit => club != null;

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _clubName =
      TextEditingController(text: widget.club?.clubName ?? '');
  late final TextEditingController _firstName =
      TextEditingController(text: widget.club?.managerFirstName ?? '');
  late final TextEditingController _lastName =
      TextEditingController(text: widget.club?.managerLastName ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.club?.managerEmail ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.club?.managerPhone ?? '');
  late final TextEditingController _managerShare = TextEditingController(
    text: widget.club?.managerShare.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _adminShare = TextEditingController(
    text: widget.club?.adminShare.toStringAsFixed(0) ?? '',
  );
  final _password = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _clubName.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _managerShare.dispose();
    _adminShare.dispose();
    _password.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  String? _requiredText(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _requiredShare(String? v) {
    final parsed = double.tryParse((v ?? '').trim());
    if (parsed == null) return 'Enter a number';
    if (parsed < 0 || parsed > 100) return '0 to 100';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.isEdit) {
        await Services.clubs.update(
          widget.club!.id,
          clubName: _clubName.text,
          managerFirstName: _firstName.text,
          managerLastName: _lastName.text,
          managerEmail: _email.text,
          managerPhone: _phone.text,
          managerShare: _num(_managerShare),
          adminShare: _num(_adminShare),
        );
      } else {
        await Services.clubs.create(
          clubName: _clubName.text,
          managerFirstName: _firstName.text,
          managerLastName: _lastName.text,
          managerEmail: _email.text,
          managerPhone: _phone.text,
          managerShare: _num(_managerShare),
          adminShare: _num(_adminShare),
          password: _password.text,
        );
      }
      if (!mounted) return;
      showSnack(context, widget.isEdit ? 'Club updated' : 'Club created');
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
    final shareTotal = _num(_managerShare) + _num(_adminShare);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit club' : 'New club')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _clubName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Club name'),
                  validator: _requiredText,
                ),
                const SizedBox(height: 24),
                Text(
                  'Manager',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'First name'),
                        validator: _requiredText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Last name'),
                        validator: _requiredText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim());
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: _requiredText,
                ),
                if (!widget.isEdit) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Manager password',
                      helperText: 'Used for the new manager login',
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Revenue split (%)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _managerShare,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Manager share'),
                        onChanged: (_) => setState(() {}),
                        validator: _requiredShare,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _adminShare,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Admin share'),
                        onChanged: (_) => setState(() {}),
                        validator: _requiredShare,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Combined ${shareTotal.toStringAsFixed(0)}% of each pot goes '
                  'to the house.',
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
                      : Text(widget.isEdit ? 'Save changes' : 'Create club'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
