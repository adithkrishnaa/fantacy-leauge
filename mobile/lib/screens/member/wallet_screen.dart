import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';

/// Credit history for a user.
///
/// Reused by the manager dashboard, which passes an explicit [userId] and
/// [title]; members see their own.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.userId, this.title});

  final String? userId;
  final String? title;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<List<WalletTransaction>> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = _load();
  }

  Future<List<WalletTransaction>> _load() async {
    final id = widget.userId ?? context.read<AuthState>().user?.id;
    if (id == null || id.isEmpty) return const [];
    final list = await Services.transactions.forUser(id);
    list.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return list;
  }

  void _reload() => setState(() => _transactions = _load());

  @override
  Widget build(BuildContext context) {
    final showsOwnWallet = widget.userId == null;
    final credits = context.watch<AuthState>().credits;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Wallet history')),
      body: Column(
        children: [
          if (showsOwnWallet)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: StatTile(
                label: 'Current balance',
                value: formatCredits(credits),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: AsyncView<List<WalletTransaction>>(
                future: _transactions,
                onRetry: _reload,
                isEmpty: (data) => data.isEmpty,
                emptyIcon: Icons.history,
                emptyTitle: 'No transactions',
                emptyMessage: 'Credit and debit activity will appear here.',
                builder: (context, items) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TransactionTile(items[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final credit = transaction.isCredit;
    final color = credit ? const Color(0xFF116A3E) : Theme.of(context).colorScheme.error;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: credit
              ? const Color(0xFFDCF5E6)
              : Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            credit ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: color,
          ),
        ),
        title: Text(
          transaction.description.isEmpty
              ? transaction.type
              : transaction.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(formatDateTime(transaction.createdAt)),
        trailing: Text(
          '${credit ? '+' : '-'}${formatCredits(transaction.amount.abs())}',
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
