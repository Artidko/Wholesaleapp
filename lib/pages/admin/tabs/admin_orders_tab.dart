// lib/pages/admin/admin_orders_tab.dart
import 'package:flutter/material.dart';
import '../../../services/order_service.dart';
import '../../../models/order.dart'; // OrderModel, OrderStatus

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

  // ---- Helpers ----
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

  // ต้องสอดคล้องกับ OrderService._isValidTransition()
  List<OrderStatus> allowedNext(OrderStatus from) => switch (from) {
        OrderStatus.pending => const <OrderStatus>[
            OrderStatus.paid,
            OrderStatus.cancelled
          ],
        OrderStatus.paid => const <OrderStatus>[
            OrderStatus.preparing,
            OrderStatus.cancelled
          ],
        OrderStatus.preparing => const <OrderStatus>[
            OrderStatus.delivering,
            OrderStatus.cancelled
          ],
        OrderStatus.delivering => const <OrderStatus>[OrderStatus.completed],
        OrderStatus.completed || OrderStatus.cancelled => const <OrderStatus>[],
      };

  @override
  Widget build(BuildContext context) {
    final selectedStatus =
        selected == 'ทั้งหมด' ? null : statusFromThai(selected);

    return Column(
      children: [
        const SizedBox(height: 8),
        // ฟิลเตอร์ด้านบน
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = filters[i];
              final sel = f == selected;
              return ChoiceChip(
                label: Text(f),
                selected: sel,
                onSelected: (_) => setState(() => selected = f),
                labelStyle: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
                selectedColor: Colors.white,
                side: BorderSide(
                    color: sel ? Colors.green : Colors.grey.shade400,
                    width: sel ? 2 : 1),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const Divider(),

        // รายการออเดอร์
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
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final o = orders[i];
                  final color = statusColor(o.status);

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('ออเดอร์ #${o.id}'),
                      subtitle: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: color),
                            ),
                            child: Text(
                              statusThai(o.status),
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('วันที่สั่ง: ${o.createdAt}',
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                      trailing: Text('฿${o.grandTotal.toStringAsFixed(0)}'),
                      onTap: () => _openDetail(context, o),
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
      builder: (_) => _AdminOrderDetail(
        order: o,
        allowedNext: allowedNext(o.status),
        onChangeStatus: (to, {String? reason}) async {
          try {
            await OrderService.instance
                .updateStatus(o.id, to, cancelReason: reason);
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

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ออเดอร์ #${o.id}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('สถานะปัจจุบัน: ${statusThai(o.status)}'),
            if (o.addressText.isNotEmpty) Text('ที่อยู่: ${o.addressText}'),
            if (o.paymentText.isNotEmpty) Text('การชำระเงิน: ${o.paymentText}'),
            const SizedBox(height: 12),

            if (widget.allowedNext.isEmpty)
              const Text('ออเดอร์นี้ปิดงานแล้ว ไม่สามารถแก้ไขสถานะได้',
                  style: TextStyle(color: Colors.grey))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ปรับสถานะ:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildStatusChips(context),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // ปุ่มลัดที่ใช้บ่อย
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.allowedNext.contains(OrderStatus.preparing))
                  OutlinedButton.icon(
                    onPressed: () =>
                        widget.onChangeStatus(OrderStatus.preparing),
                    icon: const Icon(Icons.warehouse),
                    label: const Text('เริ่มเตรียมสินค้า'),
                  ),
                if (widget.allowedNext.contains(OrderStatus.delivering))
                  OutlinedButton.icon(
                    onPressed: () =>
                        widget.onChangeStatus(OrderStatus.delivering),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('เริ่มจัดส่ง'),
                  ),
                if (widget.allowedNext.contains(OrderStatus.completed))
                  FilledButton.icon(
                    onPressed: () =>
                        widget.onChangeStatus(OrderStatus.completed),
                    icon: const Icon(Icons.done_all),
                    label: const Text('ทำเครื่องหมาย “เสร็จสิ้น”'),
                  ),
                if (widget.allowedNext.contains(OrderStatus.cancelled))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final reason = await _askCancelReason(context);
                      if (reason == null) return;
                      await widget.onChangeStatus(OrderStatus.cancelled,
                          reason: reason);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('ยกเลิกออเดอร์'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
          decoration: const InputDecoration(hintText: 'ใส่เหตุผล...'),
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
