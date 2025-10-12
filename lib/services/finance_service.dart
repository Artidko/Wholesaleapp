// lib/services/finance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance_entry.dart'; // ใช้เฉพาะ FinanceEntry/FinanceType

class FinanceService {
  FinanceService._();
  static final instance = FinanceService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('finance_entries');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  // ---------- helpers ----------
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------- write ----------
  /// บันทึกรายรับจากออเดอร์ที่ "เสร็จสิ้น" โดยส่งแค่ orderId (ไม่พึ่ง OrderModel)
  /// - กันซ้ำด้วย orderId + type=income
  /// - amount = grandTotal (fallback: subTotal + shippingFee)
  /// - date = completedAt (fallback: วันนี้) บันทึกแบบ day-only
  Future<void> recordIncomeFromCompletedOrderById(String orderId) async {
    // กันซ้ำ
    final dup = await _entries
        .where('orderId', isEqualTo: orderId)
        .where('type', isEqualTo: FinanceType.income.name)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) return;

    // ดึงออเดอร์
    final snap = await _orders.doc(orderId).get();
    final m = snap.data();
    if (m == null) return;

    // ต้องเป็น completed เท่านั้น
    final statusStr = (m['status'] ?? '').toString();
    if (statusStr != 'completed') return;

    // จำนวนเงิน
    final amount = (m.containsKey('grandTotal') && m['grandTotal'] != null)
        ? _toDouble(m['grandTotal'])
        : _toDouble(m['subTotal']) + _toDouble(m['shippingFee']);

    // โค้ดออเดอร์เพื่อแสดงในโน้ต (ถ้าไม่มี code ใช้ id)
    final codeStr = (m['code']?.toString().trim().isNotEmpty ?? false)
        ? m['code'].toString()
        : orderId;

    // วันที่ (เก็บแบบ day-only)
    DateTime when = DateTime.now();
    final completedAt = m['completedAt'];
    if (completedAt is Timestamp) when = completedAt.toDate();
    final dateOnly = _dayOnly(when);

    // สร้างเอนทรีรายรับ
    final entryRef = _entries.doc();
    final entry = FinanceEntry(
      id: entryRef.id,
      type: FinanceType.income,
      amount: amount,
      orderId: orderId,
      category: 'Order Income',
      note: 'รายรับจากออเดอร์ #$codeStr',
      date: dateOnly,
      createdAt: DateTime.now(),
    );

    await entryRef.set(entry.toMap());
  }

  /// เพิ่ม "รายจ่าย" แบบแมนนวล
  Future<void> addExpense({
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) async {
    final entryRef = _entries.doc();
    final entry = FinanceEntry(
      id: entryRef.id,
      type: FinanceType.expense,
      amount: amount,
      orderId: null,
      category: category,
      note: note,
      date: _dayOnly(date ?? DateTime.now()),
      createdAt: DateTime.now(),
    );
    await entryRef.set(entry.toMap());
  }

  // ---------- read (streams) ----------
  /// สรุปยอดรายรับ–รายจ่ายในช่วงวัน
  Stream<({double income, double expense})> watchSummary({
    required DateTime start,
    required DateTime end,
  }) {
    final startTs = Timestamp.fromDate(
        DateTime(start.year, start.month, start.day, 0, 0, 0));
    final endTs =
        Timestamp.fromDate(DateTime(end.year, end.month, end.day, 23, 59, 59));

    final q = _entries
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThanOrEqualTo: endTs);

    return q.snapshots().map((snap) {
      double income = 0, expense = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final type = (d['type'] as String?) ?? 'income';
        final amt = _toDouble(d['amount']);
        if (type == FinanceType.expense.name) {
          expense += amt;
        } else {
          income += amt;
        }
      }
      return (income: income, expense: expense);
    });
  }

  /// ลิสต์รายการการเงินในช่วงวัน (ล่าสุดอยู่บน)
  Stream<List<FinanceEntry>> watchEntries({
    required DateTime start,
    required DateTime end,
  }) {
    final startTs = Timestamp.fromDate(
        DateTime(start.year, start.month, start.day, 0, 0, 0));
    final endTs =
        Timestamp.fromDate(DateTime(end.year, end.month, end.day, 23, 59, 59));

    return _entries
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThanOrEqualTo: endTs)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => FinanceEntry.fromDoc(d)).toList());
  }
}
