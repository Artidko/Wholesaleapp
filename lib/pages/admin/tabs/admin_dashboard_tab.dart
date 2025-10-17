import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  // ---- design tokens ----
  static const double _rCard = 10; // card radius 10px
  static const double _rImage = 8; // image/icon radius 8px
  static const double _gap = 12;

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

  // ---- Load recent orders ----
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

  // ---- Robust readers ----
  num _readTotal(Map<String, dynamic> m) {
    dynamic v = m['total'] ?? m['grandTotal'] ?? m['amount'];
    v ??= (m['summary'] is Map ? (m['summary']['total']) : null);
    v ??= (m['payment'] is Map ? (m['payment']['total']) : null);

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

  Color _statusColor(ThemeData theme, String status) {
    final pri = theme.colorScheme.primary;
    switch (status) {
      case 'รอชำระ':
      case 'pending':
        return Colors.grey;
      case 'ชำระแล้ว':
      case 'paid':
        return pri.withOpacity(.75);
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
    final theme = Theme.of(context);
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

        final ordersTodayCount = docs.where((d) {
          final ts = _pickCreatedTs(d.data());
          if (ts == null) return false;
          final ms = ts.millisecondsSinceEpoch;
          return ms >= startMs && ms < endMs;
        }).length;

        num salesToday = 0;
        for (final d in docs) {
          final data = d.data();
          if (!_isCompleted(_readStatus(data))) continue;
          Timestamp? ts = _pickCompletedTs(data);
          ts ??= _pickCreatedTs(data);
          if (ts == null) continue;
          final ms = ts.millisecondsSinceEpoch;
          if (ms < startMs || ms >= endMs) continue;
          salesToday += _readTotal(data);
        }

        final pri = theme.colorScheme.primary;
        final faintPri = pri.withOpacity(.06);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),

            // ===== KPIs =====
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_rounded,
                      size: 18, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text('ภาพรวมวันนี้', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                _KpiCard(
                  title: 'ยอดขายรวมวันนี้',
                  value: thb.format(salesToday),
                  icon: Icons.payments_outlined,
                  color: faintPri,
                  elevation: 1,
                  radius: _rCard,
                ),
                _KpiCard(
                  title: 'คำสั่งซื้อวันนี้',
                  value: '$ordersTodayCount',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.blue.withOpacity(.06),
                  elevation: 1,
                  radius: _rCard,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ===== Recent Orders =====
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text('คำสั่งซื้อล่าสุด', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rCard)),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 14), // กันชายล่างนิด
                child: docs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ยังไม่มีคำสั่งซื้อ')),
                      )
                    : Column(
                        children: [
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, thickness: .5),
                            itemBuilder: (_, i) {
                              final data = docs[i].data();
                              final id = docs[i].id;
                              final total = _readTotal(data);
                              final status = _readStatus(data);
                              final ts = _pickCreatedTs(data) ??
                                  _pickCompletedTs(data);
                              final dt = ts?.toDate();
                              final c = _statusColor(theme, status);

                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(0, 6, 0, 10),
                                isThreeLine: true,
                                minVerticalPadding: 10,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(_rImage),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    color: c.withOpacity(.10),
                                    child: Icon(Icons.shopping_bag_outlined,
                                        color: c),
                                  ),
                                ),
                                title: Text(
                                  '$id • ${_readCustomer(data)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  dt != null
                                      ? DateFormat('dd/MM/yyyy HH:mm')
                                          .format(dt)
                                      : '—',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                                // >>> ป้องกัน overflow: บังคับความสูงฝั่งขวาเท่า 44px <<<
                                trailing: SizedBox(
                                  height: 44,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        thb.format(total),
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: pri.withOpacity(.90),
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: c.withOpacity(.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: c.withOpacity(.25),
                                              width: .5),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: c,
                                            fontSize: 12,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(
                              height: 2), // กัน clipping ชายล่าง card
                        ],
                      ),
              ),
            ),

            // debug (ลบได้)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'debug: today range ${DateFormat("dd/MM HH:mm").format(_startOfToday)}–'
                '${DateFormat("dd/MM HH:mm").format(_endOfToday)}',
                style: theme.textTheme.bodySmall
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
  final double elevation;
  final double radius;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.elevation = 1,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pri = theme.colorScheme.primary;

    return SizedBox(
      width: 280,
      child: Card(
        color: color,
        elevation: elevation,
        shadowColor: Colors.black12,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: pri.withOpacity(.95),
                      ),
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
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('เกิดข้อผิดพลาด'),
        subtitle: Text(message),
      ),
    );
  }
}
