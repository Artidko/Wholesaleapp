// lib/services/finance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance_entry.dart'; // FinanceEntry, FinanceType

class FinanceService {
  FinanceService._();
  static final instance = FinanceService._();

  final _db = FirebaseFirestore.instance;

  /// คอลเลกชันหลัก
  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('finance_entries');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  // ---------- helpers ----------
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  /// ตัดเวลาให้เหลือแค่วันเดียว (กลางคืน 00:00)
  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// server timestamp
  Map<String, dynamic> _serverCreatedAt() =>
      {'createdAt': FieldValue.serverTimestamp()};

  // ---------- write ----------
  /// (แนะนำ) ใช้ docId แบบคงที่เพื่อกันซ้ำจริง: income ของออเดอร์เดียว = 1 เอนทรี
  /// docId: inc_{orderId}
  String _incomeDocId(String orderId) => 'inc_$orderId';

  /// อัปเสิร์ต "รายรับ" จากออเดอร์ที่สถานะ "completed"
  /// - กันซ้ำด้วย docId = inc_{orderId}
  /// - amount = grandTotal (fallback: subTotal + shippingFee)
  /// - date = completedAt (fallback: วันนี้) — เก็บแบบ day-only
  Future<void> upsertIncomeFromOrderId(String orderId) async {
    final orderSnap = await _orders.doc(orderId).get();
    final m = orderSnap.data();
    if (m == null) return;

    final statusStr = (m['status'] ?? '').toString();
    if (statusStr != 'completed') return;

    final amount = (m.containsKey('grandTotal') && m['grandTotal'] != null)
        ? _toDouble(m['grandTotal'])
        : _toDouble(m['subTotal']) + _toDouble(m['shippingFee']);

    final codeStr = (m['code']?.toString().trim().isNotEmpty ?? false)
        ? m['code'].toString()
        : orderId;

    DateTime when = DateTime.now();
    final completedAt = m['completedAt'];
    if (completedAt is Timestamp) when = completedAt.toDate();
    final dateOnly = _dayOnly(when);

    final docId = _incomeDocId(orderId);
    final ref = _entries.doc(docId);

    final entry = FinanceEntry(
      id: docId,
      type: FinanceType.income,
      amount: amount,
      orderId: orderId,
      category: 'Order Income',
      note: 'รายรับจากออเดอร์ #$codeStr',
      date: dateOnly,
      createdAt: DateTime.now(), // จะถูกแทนด้วย serverTimestamp ตอน set()
    );

    // ใช้ set(..., merge: true) เพื่อให้เป็น upsert และไม่ทำให้ field อื่นหาย
    await ref.set({
      ...entry.toMap(),
      ..._serverCreatedAt(),
    }, SetOptions(merge: true));
  }

  /// (เวอร์ชันที่คุณมี) ถ้าต้องการ strictly "บันทึกถ้ายังไม่เคยมี" ให้ใช้ตัวนี้
  Future<void> recordIncomeFromCompletedOrderById(String orderId) async {
    final docId = _incomeDocId(orderId);
    final existing = await _entries.doc(docId).get();
    if (existing.exists) return;
    await upsertIncomeFromOrderId(orderId);
  }

  /// เพิ่ม "รายจ่าย" แบบแมนนวล (amount ให้เป็นบวก)
  Future<void> addExpense({
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) async {
    final ref = _entries.doc();
    final entry = FinanceEntry(
      id: ref.id,
      type: FinanceType.expense,
      amount: amount,
      orderId: null,
      category: category,
      note: note,
      date: _dayOnly(date ?? DateTime.now()),
      createdAt: DateTime.now(), // จะถูกแทนด้วย serverTimestamp
    );
    await ref.set({
      ...entry.toMap(),
      ..._serverCreatedAt(),
    });
  }

  /// แก้ไข "รายจ่าย" ที่มีอยู่ (หรือจะใช้กับ income ก็ได้ ถ้ารู้ id)
  Future<void> updateExpense(FinanceEntry entry) async {
    await _entries.doc(entry.id).update(entry.toMap());
  }

  /// ลบเอนทรี การเงิน (ใช้ได้ทั้ง income/expense)
  Future<void> deleteEntry(String id) async {
    await _entries.doc(id).delete();
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
        final type = (d['type'] as String?) ?? FinanceType.income.name;
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

  // ---------- utilities ----------
  /// รันไล่ sync รายรับจากออเดอร์ชุดหนึ่ง (เช่นตอน maintenance)
  Future<void> upsertIncomeForOrderIds(Iterable<String> orderIds) async {
    for (final id in orderIds) {
      await upsertIncomeFromOrderId(id);
    }
  }
}
