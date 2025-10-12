import 'package:cloud_firestore/cloud_firestore.dart';

enum FinanceType { income, expense }

class FinanceEntry {
  final String id;
  final FinanceType type; // income | expense
  final double amount; // จำนวนเงิน (บวกเสมอ)
  final String? orderId; // ผูกกับออเดอร์ (รายรับอัตโนมัติ)
  final String
      category; // เช่น "Order Income", "Delivery Cost", "COGS", "Other"
  final String note; // โน้ตเพิ่มเติม
  final DateTime date; // วันที่เกิดรายการ (ใช้ตอนสรุปช่วงเวลา)
  final DateTime createdAt; // วันที่บันทึกเข้าระบบ

  FinanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.createdAt,
    this.orderId,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'amount': amount,
        'orderId': orderId,
        'category': category,
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory FinanceEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FinanceEntry(
      id: doc.id,
      type: (d['type'] == 'expense') ? FinanceType.expense : FinanceType.income,
      amount: (d['amount'] as num).toDouble(),
      orderId: d['orderId'] as String?,
      category: (d['category'] ?? '') as String,
      note: (d['note'] ?? '') as String,
      date: (d['date'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
