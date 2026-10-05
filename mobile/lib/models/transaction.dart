import 'json_utils.dart';

/// A credit movement on a wallet.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.transactionId,
    required this.userId,
    required this.amount,
    required this.type,
    this.description = '',
    this.createdAt,
  });

  final String id;
  final String transactionId;
  final String userId;
  final double amount;
  final String type;
  final String description;
  final DateTime? createdAt;

  /// The backend uses a handful of type strings; anything that is not an
  /// explicit debit is treated as money in.
  bool get isCredit {
    final t = type.toLowerCase();
    return !(t.contains('debit') ||
        t.contains('deduct') ||
        t.contains('withdraw'));
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: idOf(json),
        transactionId: asString(json['transactionId']),
        userId: relationId(json['user']) ?? '',
        amount: asDouble(json['amount']),
        type: asString(json['type']),
        description: asString(json['description']),
        createdAt: asDate(json['createdAt']),
      );
}
