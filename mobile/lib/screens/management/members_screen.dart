import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../member/wallet_screen.dart';

/// Club roster with credit controls.
///
/// [clubId] is set by admins to scope to one club; a manager's own club is
/// implied by the endpoint.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, this.clubId, this.title});

  final String? clubId;
  final String? title;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late Future<List<AppUser>> _members;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _members = Services.clubs.members(clubId: widget.clubId);
  }

  void _reload() => setState(
        () => _members = Services.clubs.members(clubId: widget.clubId),
      );

  Future<void> _adjustCredit(AppUser member, {required bool add}) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(add ? 'Add credits' : 'Deduct credits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${member.fullName} · ${formatCredits(member.credits)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(context, value);
            },
            child: Text(add ? 'Add' : 'Deduct'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;

    try {
      if (add) {
        await Services.clubs.addCredit(member.id, amount);
      } else {
        await Services.clubs.deductCredit(member.id, amount);
      }
      if (!mounted) return;
      showSnack(
        context,
        '${formatCredits(amount)} ${add ? 'added' : 'deducted'}',
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _remove(AppUser member) async {
    final ok = await confirm(
      context,
      title: 'Remove member',
      message: 'Remove ${member.fullName} from this club?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Services.clubs.removeMember(member.id);
      if (!mounted) return;
      showSnack(context, 'Member removed');
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _addExisting() async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add existing member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the phone number of a registered member to add them to '
              'this club.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (phone == null || phone.isEmpty) return;

    try {
      await Services.clubs
          .addExistingMember(phoneNumber: phone, clubId: widget.clubId);
      if (!mounted) return;
      showSnack(context, 'Member added');
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _registerNew() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RegisterMemberScreen(clubId: widget.clubId),
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Members')),
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'existing') _addExisting();
          if (v == 'new') _registerNew();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'new',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_add_outlined),
              title: Text('Register new member'),
            ),
          ),
          PopupMenuItem(
            value: 'existing',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.group_add_outlined),
              title: Text('Add existing by phone'),
            ),
          ),
        ],
        child: FloatingActionButton.extended(
          onPressed: null,
          icon: const Icon(Icons.add),
          label: const Text('Add member'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: AsyncView<List<AppUser>>(
                future: _members,
                onRetry: _reload,
                isEmpty: (data) => data.isEmpty,
                emptyIcon: Icons.people_outline,
                emptyTitle: 'No members',
                emptyMessage: 'Add members so they can place bets.',
                builder: (context, members) {
                  final filtered = _query.isEmpty
                      ? members
                      : members
                          .where((m) =>
                              m.fullName.toLowerCase().contains(_query) ||
                              m.phoneNumber.contains(_query))
                          .toList();

                  if (filtered.isEmpty) {
                    return const MessageView(
                      icon: Icons.search_off,
                      title: 'No matches',
                      message: 'No member matches that search.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final member = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.firstName.isEmpty
                                  ? '?'
                                  : member.firstName[0].toUpperCase(),
                            ),
                          ),
                          title: Text(member.fullName),
                          subtitle: Text(
                            '${member.phoneNumber}\n'
                            '${formatCredits(member.credits)}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'add':
                                  _adjustCredit(member, add: true);
                                case 'deduct':
                                  _adjustCredit(member, add: false);
                                case 'wallet':
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WalletScreen(
                                        userId: member.id,
                                        title: member.fullName,
                                      ),
                                    ),
                                  );
                                case 'remove':
                                  _remove(member);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'add',
                                child: Text('Add credits'),
                              ),
                              PopupMenuItem(
                                value: 'deduct',
                                child: Text('Deduct credits'),
                              ),
                              PopupMenuItem(
                                value: 'wallet',
                                child: Text('Wallet history'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove from club'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Creates a brand-new member account directly inside the club.
class _RegisterMemberScreen extends StatefulWidget {
  const _RegisterMemberScreen({this.clubId});

  final String? clubId;

  @override
  State<_RegisterMemberScreen> createState() => _RegisterMemberScreenState();
}

class _RegisterMemberScreenState extends State<_RegisterMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _countryCode = '+91';
  bool _busy = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Services.clubs.registerMember(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        countryCode: _countryCode,
        phoneNumber: _phone.text,
        password: _password.text,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      showSnack(context, 'Member registered');
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
      appBar: AppBar(title: const Text('Register member')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'First name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: DropdownButtonFormField<String>(
                        initialValue: _countryCode,
                        decoration: const InputDecoration(labelText: 'Code'),
                        items: const [
                          DropdownMenuItem(value: '+91', child: Text('+91')),
                          DropdownMenuItem(value: '+971', child: Text('+971')),
                          DropdownMenuItem(value: '+966', child: Text('+966')),
                          DropdownMenuItem(value: '+974', child: Text('+974')),
                          DropdownMenuItem(value: '+968', child: Text('+968')),
                        ],
                        onChanged: (v) =>
                            setState(() => _countryCode = v ?? '+91'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Phone number'),
                        validator: (v) => (v == null || v.trim().length < 7)
                            ? 'Enter a valid number'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email (optional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'At least 6 characters' : null,
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
                      : const Text('Register member'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
