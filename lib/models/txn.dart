import 'package:cloud_firestore/cloud_firestore.dart';

enum TxnType { income, expense }

enum TxnStatus { confirmed, pending, voided }

class TxnModel {
  final String id;
  final TxnType type;
  final double amount;
  final String category;
  final String desc;
  final String method;
  final TxnStatus status;
  final String refType;
  final String refId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String note;

  const TxnModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.desc,
    required this.method,
    required this.status,
    required this.refType,
    required this.refId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.note,
  });

  factory TxnModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TxnModel(
      id: doc.id,
      type: (d['type'] == 'income') ? TxnType.income : TxnType.expense,
      amount: (d['amount'] ?? 0).toDouble(),
      category: d['category'] ?? '',
      desc: d['desc'] ?? '',
      method: d['method'] ?? '',
      status: switch (d['status']) {
        'pending' => TxnStatus.pending,
        'void' || 'voided' => TxnStatus.voided,
        _ => TxnStatus.confirmed,
      },
      refType: d['refType'] ?? '',
      refId: d['refId'] ?? '',
      userId: d['userId'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: (d['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      note: d['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'amount': amount,
        'category': category,
        'desc': desc,
        'method': method,
        'status': switch (status) {
          TxnStatus.pending => 'pending',
          TxnStatus.voided => 'void',
          _ => 'confirmed',
        },
        'refType': refType,
        'refId': refId,
        'userId': userId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'tags': tags,
        'note': note,
      };

  bool get isIncome => type == TxnType.income;
  bool get isExpense => type == TxnType.expense;
}
