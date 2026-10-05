import 'package:flutter/material.dart';

import '../../models/bet.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

class MyBetsScreen extends StatefulWidget {
  const MyBetsScreen({super.key});

  @override
  State<MyBetsScreen> createState() => _MyBetsScreenState();
}

class _MyBetsScreenState extends State<MyBetsScreen> {
  late Future<List<Bet>> _bets;

  @override
  void initState() {
    super.initState();
    _bets = Services.betting.myBets();
  }

  void _reload() => setState(() => _bets = Services.betting.myBets());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bets')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: AsyncView<List<Bet>>(
          future: _bets,
          onRetry: _reload,
          isEmpty: (data) => data.isEmpty,
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'No bets yet',
          emptyMessage: 'Bets you place will show up here.',
          builder: (context, bets) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: bets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final bet = bets[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CombinationChips(bet.combination),
                          const Spacer(),
                          Text(
                            formatCredits(bet.betAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatDateTime(bet.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const Spacer(),
                          if (bet.result != null && bet.result!.isNotEmpty)
                            StatusChip(bet.result!),
                        ],
                      ),
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
