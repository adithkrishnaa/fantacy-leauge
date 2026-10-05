import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<ReferralStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = Services.auth.referralStats();
  }

  void _reload() => setState(() => _stats = Services.auth.referralStats());

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showSnack(context, 'Referral code copied');
  }

  Future<void> _copyLink(String code) async {
    // Matches the web sign-up link the React app shares.
    final link = 'https://fantacyleauge.com/register?ref=$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    showSnack(context, 'Invite link copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Refer & earn')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: AsyncView<ReferralStats>(
          future: _stats,
          onRetry: _reload,
          builder: (context, stats) {
            final code = stats.referralCode ?? '';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your referral code',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          code.isEmpty ? '—' : code,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (code.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copy(code),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('Copy code'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _copyLink(code),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  icon: const Icon(Icons.link, size: 18),
                                  label: const Text('Copy link'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'People referred',
                        value: '${stats.referralCount}',
                        icon: Icons.group_add_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Earnings',
                        value: formatCredits(stats.referralEarnings),
                        icon: Icons.savings_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Referred members',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (stats.referredUsers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nobody has signed up with your code yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...stats.referredUsers.map(
                    (u) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            u.fullName.isEmpty
                                ? '?'
                                : u.fullName[0].toUpperCase(),
                          ),
                        ),
                        title: Text(u.fullName),
                        subtitle: Text(formatDate(u.createdAt)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
