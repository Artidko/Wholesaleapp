// lib/pages/admin/tabs/admin_orders_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/order_service.dart';
import '../../../models/order.dart';
import '../../../services/driver_location_service.dart';

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  final filters = <String>[
    'ทั้งหมด',
    'รอชำระ',
    'ชำระแล้ว',
    'กำลังเตรียม',
    'กำลังจัดส่ง',
    'เสร็จสิ้น',
    'ยกเลิก',
  ];
  String selected = 'ทั้งหมด';

  String statusThai(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'รอชำระ',
        OrderStatus.paid => 'ชำระแล้ว',
        OrderStatus.preparing => 'กำลังเตรียม',
        OrderStatus.delivering => 'กำลังจัดส่ง',
        OrderStatus.completed => 'เสร็จสิ้น',
        OrderStatus.cancelled => 'ยกเลิก',
      };

  OrderStatus? statusFromThai(String s) => switch (s) {
        'รอชำระ' => OrderStatus.pending,
        'ชำระแล้ว' => OrderStatus.paid,
        'กำลังเตรียม' => OrderStatus.preparing,
        'กำลังจัดส่ง' => OrderStatus.delivering,
        'เสร็จสิ้น' => OrderStatus.completed,
        'ยกเลิก' => OrderStatus.cancelled,
        _ => null,
      };

  Color statusColor(OrderStatus s) => switch (s) {
        OrderStatus.pending => Colors.orange,
        OrderStatus.paid => Colors.blue,
        OrderStatus.preparing => Colors.indigo,
        OrderStatus.delivering => Colors.teal,
        OrderStatus.completed => Colors.green,
        OrderStatus.cancelled => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final selectedStatus =
        selected == 'ทั้งหมด' ? null : statusFromThai(selected);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.receipt_long,
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 8),
          Text(
            'คำสั่งซื้อ',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );

    final filterBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        elevation: 1,
        shadowColor: Colors.black12,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = filters[i];
              final sel = f == selected;
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(
                    color:
                        sel ? primary.withOpacity(.55) : Colors.grey.shade300,
                    width: sel ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: sel ? primary.withOpacity(.06) : null,
                  foregroundColor: Colors.black87,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() => selected = f),
                child: Text(f),
              );
            },
          ),
        ),
      ),
    );

    return Column(
      children: [
        header,
        filterBar,
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Divider(height: 16),
        ),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: OrderService.instance.watchAll(status: selectedStatus),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
              }
              final orders = snap.data ?? const <OrderModel>[];
              if (orders.isEmpty) {
                return const Center(child: Text('ยังไม่มีคำสั่งซื้อ'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final o = orders[i];
                  final sc = statusColor(o.status);

                  return Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openDetail(context, o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: sc.withOpacity(.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.receipt_long, color: sc),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ออเดอร์ #${o.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '฿${o.grandTotal.toStringAsFixed(0)}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: primary.withOpacity(.85),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sc.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: sc),
                                  ),
                                  child: Text(
                                    statusThai(o.status),
                                    style: TextStyle(
                                      color: sc,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  'วันที่สั่ง: ${o.createdAt}',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDetail(BuildContext context, OrderModel o) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AdminOrderDetail(
        order: o,
        allowedNext: OrderStatus.values.toList(),
        onChangeStatus: (to, {String? reason}) async {
          try {
            await OrderService.instance
                .updateStatus(o.id, to, cancelReason: reason, force: true);
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('อัปเดตสถานะเป็น "${statusThai(to)}" สำเร็จ')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('อัปเดตล้มเหลว: $e')),
            );
          }
        },
      ),
    );
  }
}

class _AdminOrderDetail extends StatefulWidget {
  final OrderModel order;
  final List<OrderStatus> allowedNext;
  final Future<void> Function(OrderStatus to, {String? reason}) onChangeStatus;

  const _AdminOrderDetail({
    required this.order,
    required this.allowedNext,
    required this.onChangeStatus,
  });

  @override
  State<_AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends State<_AdminOrderDetail> {
  String statusThai(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'รอชำระ',
        OrderStatus.paid => 'ชำระแล้ว',
        OrderStatus.preparing => 'กำลังเตรียม',
        OrderStatus.delivering => 'กำลังจัดส่ง',
        OrderStatus.completed => 'เสร็จสิ้น',
        OrderStatus.cancelled => 'ยกเลิก',
      };

  String _money(num n) => '฿${n.toStringAsFixed(0)}';

  Widget _secHeader(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 6),
          Text(text,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      fontSize: bold ? 16 : 14,
    );
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: style.copyWith(fontWeight: FontWeight.w500))),
        Text(value, style: style),
      ],
    );
  }

  Widget _lineTile(OrderLine l) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: l.imageUrl.isNotEmpty
              ? Image.network(l.imageUrl,
                  width: 48, height: 48, fit: BoxFit.cover)
              : Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('x${l.qty} • ${_money(l.price)}',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Text(_money(l.lineTotal),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ---------- แสดงสลิปโอนเงิน ----------
  Widget _paymentSlipSection(String orderId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('กำลังโหลดสลิป…'),
              ],
            ),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Text('ไม่พบข้อมูลออเดอร์');
        }

        final data = snap.data!.data()!;
        final pay = (data['payment'] ?? {}) as Map<String, dynamic>;
        final slipUrl = (pay['slipUrl'] ?? '') as String;
        final review = (pay['reviewStatus'] ?? 'pending') as String;

        Color chipColor() {
          switch (review) {
            case 'approved':
              return Colors.green;
            case 'rejected':
              return Colors.red;
            case 'pending':
            default:
              return Colors.orange;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16),
                const SizedBox(width: 6),
                const Text('สลิปการโอน',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Chip(
                  label: Text(review),
                  backgroundColor: chipColor().withOpacity(.12),
                  side: BorderSide(color: chipColor()),
                  labelStyle: TextStyle(color: chipColor()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (slipUrl.isEmpty)
              const Text('ลูกค้ายังไม่แนบสลิป',
                  style: TextStyle(color: Colors.black54))
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: InkWell(
                    onTap: () => _showFullScreenSlip(slipUrl),
                    child: Image.network(
                      slipUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xfff2f2f2),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: Colors.grey),
                            SizedBox(height: 6),
                            Text('โหลดรูปไม่สำเร็จ',
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('เปิดเต็มจอ'),
                    onPressed: () => _showFullScreenSlip(slipUrl),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('คัดลอกลิงก์'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: slipUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  void _showFullScreenSlip(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: .5,
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ---------- แชร์ตำแหน่ง ----------
  Future<void> _assignMeAsDriver(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw 'ยังไม่ได้เข้าสู่ระบบ';
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'driverId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _startShare() async {
    final id = widget.order.id;
    await _assignMeAsDriver(id);
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    await FirebaseFirestore.instance.collection('orders').doc(id).set({
      'trackingActive': true,
      'current': {
        'sessionId': sessionId,
        'ts': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await DriverLocationService.instance
          .startTrackingOrder(id, sessionId: sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เริ่มแชร์ตำแหน่งแล้ว')),
        );
      }
    } catch (e) {
      await FirebaseFirestore.instance.collection('orders').doc(id).set({
        'trackingActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เริ่มแชร์ไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _stopShare() async {
    final id = widget.order.id;
    try {
      await DriverLocationService.instance.stop();
    } finally {
      await FirebaseFirestore.instance.collection('orders').doc(id).set({
        'trackingActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('หยุดแชร์ตำแหน่งแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final o = widget.order;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('ออเดอร์ #${o.id}',
                        style: theme.textTheme.titleLarge),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _money(o.grandTotal),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: primary.withOpacity(.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('สถานะปัจจุบัน: ${statusThai(o.status)}'),
              if (o.addressText.isNotEmpty) Text('ที่อยู่: ${o.addressText}'),
              if (o.paymentText.isNotEmpty)
                Text('การชำระเงิน: ${o.paymentText}'),
              const SizedBox(height: 12),

              _secHeader(Icons.shopping_bag_outlined, 'รายการสินค้า'),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: o.lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _lineTile(o.lines[i]),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _totalRow('ยอดสินค้า', _money(o.subTotal)),
                    const SizedBox(height: 6),
                    _totalRow('ค่าส่ง', _money(o.shippingFee)),
                    const Divider(height: 16),
                    _totalRow('ยอดสุทธิ', _money(o.grandTotal), bold: true),
                  ],
                ),
              ),

              // ✅ แทรก Section สลิปโอนเงิน
              const SizedBox(height: 12),
              _secHeader(Icons.receipt_long, 'การชำระเงิน / สลิป'),
              _paymentSlipSection(o.id),
              const SizedBox(height: 12),

              if (widget.allowedNext.isEmpty)
                const Text('ออเดอร์นี้ปิดงานแล้ว ไม่สามารถแก้ไขสถานะได้',
                    style: TextStyle(color: Colors.grey))
              else ...[
                _secHeader(Icons.flag_circle_outlined, 'ปรับสถานะ'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildStatusChips(context),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),

              _secHeader(Icons.location_searching, 'แชร์ตำแหน่งผู้ส่ง'),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .doc(o.id)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final sharing = (data?['trackingActive'] == true);
                  final canStart =
                      o.status == OrderStatus.delivering && !sharing;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: canStart ? _startShare : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('เริ่มแชร์ตำแหน่ง'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: sharing ? _stopShare : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('หยุดแชร์'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sharing
                            ? 'กำลังแชร์พิกัดจากอุปกรณ์นี้...'
                            : (o.status == OrderStatus.delivering
                                ? 'แตะ “เริ่มแชร์ตำแหน่ง” เพื่อส่งพิกัดเรียลไทม์'
                                : 'ต้องอยู่สถานะ "กำลังจัดส่ง" จึงจะเริ่มแชร์พิกัดได้'),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12.5),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStatusChips(BuildContext context) {
    final next = widget.allowedNext.toSet();
    final current = widget.order.status;

    final sequence = <OrderStatus>[
      OrderStatus.pending,
      OrderStatus.paid,
      OrderStatus.preparing,
      OrderStatus.delivering,
      OrderStatus.completed,
      OrderStatus.cancelled,
    ];

    Color colorOf(OrderStatus s) => switch (s) {
          OrderStatus.pending => Colors.grey,
          OrderStatus.paid => Colors.blue,
          OrderStatus.preparing => Colors.indigo,
          OrderStatus.delivering => Colors.teal,
          OrderStatus.completed => Colors.green,
          OrderStatus.cancelled => Colors.red,
        };

    return sequence.map((s) {
      final isCurrent = s == current;
      final canGo = next.contains(s);
      final border = isCurrent ? Colors.green : colorOf(s);

      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent) const Icon(Icons.check, size: 16),
            if (isCurrent) const SizedBox(width: 6),
            Text(statusThai(s)),
          ],
        ),
        selected: isCurrent,
        onSelected: (!canGo || isCurrent)
            ? null
            : (_) async {
                if (s == OrderStatus.cancelled) {
                  final reason = await _askCancelReason(context);
                  if (reason == null) return;
                  await widget.onChangeStatus(s, reason: reason);
                } else {
                  await widget.onChangeStatus(s);
                }
              },
        backgroundColor: Colors.white,
        selectedColor: Colors.white,
        labelStyle: TextStyle(
          color: isCurrent ? border : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: border, width: isCurrent ? 2 : 1),
        visualDensity: VisualDensity.compact,
      );
    }).toList();
  }

  Future<String?> _askCancelReason(BuildContext context) async {
    final ctl = TextEditingController(text: 'แอดมินยกเลิก');
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('เหตุผลการยกเลิก'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            hintText: 'ใส่เหตุผล...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctl.text.trim()),
              child: const Text('บันทึก')),
        ],
      ),
    );
  }
}
