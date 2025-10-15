import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  // ---- Day range (local) ----
  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endOfToday => _startOfToday.add(const Duration(days: 1));

  // ---- Timestamp converters ----
  Timestamp? _toTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v;
    if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
    if (v is double) return Timestamp.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) {
      try {
        return Timestamp.fromDate(DateTime.parse(v).toLocal());
      } catch (_) {}
    }
    return null;
  }

  Timestamp? _pickCreatedTs(Map<String, dynamic> m) {
    for (final k in const ['createdAt', 'created_at']) {
      final ts = _toTs(m[k]);
      if (ts != null) return ts;
    }
    return null;
  }

  Timestamp? _pickCompletedTs(Map<String, dynamic> m) {
    for (final k in const ['completedAt']) {
      final ts = _toTs(m[k]);
      if (ts != null) return ts;
    }
    return null;
  }

  // โหลดออเดอร์ก้อนใหญ่ แล้วคำนวณใน client
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _recentOrdersAll(
      {int limit = 500}) {
    final db = FirebaseFirestore.instance;
    return db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs);
  }

  // ---- Read helpers (ทนทาน) ----
  num _readTotal(Map<String, dynamic> m) {
    dynamic v = m['total'] ?? m['grandTotal'] ?? m['amount'];
    // เผื่อเก็บไว้ใต้ nested objects
    v ??= (m['summary'] is Map ? (m['summary']['total']) : null);
    v ??= (m['payment'] is Map ? (m['payment']['total']) : null);

    // ถ้าไม่มี total ให้รวมจาก items[]
    if (v == null && m['items'] is List) {
      num sum = 0;
      for (final it in (m['items'] as List)) {
        if (it is Map) {
          final line = it['lineTotal'] ?? it['total'];
          if (line is num) {
            sum += line;
            continue;
          }
          final price = it['price'];
          final qty = it['qty'] ?? it['quantity'];
          if (price is num && qty is num) sum += price * qty;
        }
      }
      return sum;
    }

    if (v is int) return v;
    if (v is double) return v;
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v.replaceAll(',', ''));
      return n ?? 0;
    }
    return 0;
  }

  String _readStatus(Map<String, dynamic> m) =>
      (m['status'] ?? m['orderStatus'] ?? 'ไม่ระบุ').toString();

  bool _isCompleted(String s) {
    final t = s.trim().toLowerCase();
    return t == 'completed' || t == 'เสร็จสิ้น';
  }

  String _readCustomer(Map<String, dynamic> m) =>
      (m['customerName'] ?? m['customer'] ?? m['userName'] ?? 'ไม่ระบุ')
          .toString();

  Color _statusColor(String status) {
    switch (status) {
      case 'รอชำระ':
      case 'pending':
        return Colors.grey;
      case 'ชำระแล้ว':
      case 'paid':
        return Colors.blue;
      case 'กำลังเตรียม':
      case 'preparing':
        return Colors.orange;
      case 'กำลังจัดส่ง':
      case 'delivering':
        return Colors.deepPurple;
      case 'เสร็จสิ้น':
      case 'completed':
        return Colors.green;
      case 'ยกเลิก':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thb = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
    final startMs = _startOfToday.millisecondsSinceEpoch;
    final endMs = _endOfToday.millisecondsSinceEpoch;

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _recentOrdersAll(limit: 500),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorTile('โหลดข้อมูลไม่สำเร็จ: ${snap.error}');
        }
        final loading = snap.connectionState == ConnectionState.waiting;
        final docs = snap.data ?? [];

        // --- KPI: คำสั่งซื้อวันนี้ (createdAt ภายในวัน) ---
        final ordersTodayCount = docs.where((d) {
          final ts = _pickCreatedTs(d.data());
          if (ts == null) return false;
          final ms = ts.millisecondsSinceEpoch;
          return ms >= startMs && ms < endMs;
        }).length;

        // --- KPI: ยอดขายรวมวันนี้ (completed + completedAt ภายในวัน; ถ้าไม่มี completedAt ให้ fallback createdAt) ---
        num salesToday = 0;
        for (final d in docs) {
          final data = d.data();
          if (!_isCompleted(_readStatus(data))) continue;

          Timestamp? ts = _pickCompletedTs(data);
          ts ??=
              _pickCreatedTs(data); // fallback กรณีเอกสารเก่าไม่มี completedAt

          if (ts == null) continue;
          final ms = ts.millisecondsSinceEpoch;
          if (ms < startMs || ms >= endMs) continue;

          salesToday += _readTotal(data);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),

            // KPIs
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  title: 'ยอดขายรวมวันนี้',
                  value: thb.format(salesToday),
                  icon: Icons.payments_outlined,
                  color: Colors.green.shade50,
                ),
                _KpiCard(
                  title: 'คำสั่งซื้อวันนี้',
                  value: '$ordersTodayCount',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.blue.shade50,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recent Orders (เดิม)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('คำสั่งซื้อล่าสุด',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ยังไม่มีคำสั่งซื้อ')),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final data = docs[i].data();
                          final id = docs[i].id;
                          final total = _readTotal(data);
                          final status = _readStatus(data);
                          final ts =
                              _pickCreatedTs(data) ?? _pickCompletedTs(data);
                          final dt = ts?.toDate();
                          final c = _statusColor(status);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: c.withOpacity(.15),
                              child:
                                  Icon(Icons.shopping_bag_outlined, color: c),
                            ),
                            title: Text('$id • ${_readCustomer(data)}'),
                            subtitle: Text(
                              dt != null
                                  ? DateFormat('dd/MM/yyyy HH:mm').format(dt)
                                  : '—',
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(thb.format(total)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(status,
                                      style: TextStyle(color: c, fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // (optional) debug – เอาไว้ช่วงเทส แล้วค่อยลบออก
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'debug: today orders=$ordersTodayCount, sales=${thb.format(salesToday)} '
                'range=${DateFormat("dd/MM HH:mm").format(_startOfToday)}–${DateFormat("dd/MM HH:mm").format(_endOfToday)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: Colors.black87)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile(this.message);
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('เกิดข้อผิดพลาด'),
        subtitle: Text(message),
      ),
    );
  }
}
