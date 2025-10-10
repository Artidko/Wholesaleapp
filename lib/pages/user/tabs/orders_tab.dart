import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/widgets.dart'; // ใช้ OrderStatusChip
import '../../../services/order_service.dart';
import '../../../models/order.dart';
import '../../widgets/order_view_page.dart'; // เปิดรายละเอียดด้วย orderId

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  // ฟิลเตอร์ (มี "ทั้งหมด" เพื่อกันหลงสถานะ)
  final filters = const [
    'ทั้งหมด',
    'ชำระแล้ว',
    'กำลังจัดส่ง',
    'เสร็จสิ้น',
    'ยกเลิก'
  ];
  String selected = 'ทั้งหมด';

  // TH -> enum (ต้องตรงกับ enum ของโมเดล: pending, paid, preparing, delivering, completed, cancelled)
  final Map<String, OrderStatus> _thToStatus = const {
    'ชำระแล้ว': OrderStatus.paid,
    'กำลังจัดส่ง': OrderStatus.delivering,
    'เสร็จสิ้น': OrderStatus.completed,
    'ยกเลิก': OrderStatus.cancelled,
  };

  // flag: ถ้า index ยังไม่พร้อม จะ fallback ไปใช้ stream ที่ไม่ orderBy
  bool _fallbackNoOrder = false;

  // enum -> TH
  String _statusToTh(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'รอดำเนินการ';
      case OrderStatus.paid:
        return 'ชำระแล้ว';
      case OrderStatus.preparing:
        return 'กำลังเตรียมสินค้า';
      case OrderStatus.delivering:
        return 'กำลังจัดส่ง';
      case OrderStatus.completed:
        return 'เสร็จสิ้น';
      case OrderStatus.cancelled:
        return 'ยกเลิก';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบเพื่อดูคำสั่งซื้อ'));
    }

    final stream = _fallbackNoOrder
        ? OrderService.instance
            .watchMyOrdersNoOrder(user.uid) // สำรอง (ไม่ orderBy)
        : OrderService.instance
            .watchMyOrders(user.uid); // ปกติ (where + orderBy)

    return Column(
      children: [
        const SizedBox(height: 8),

        // ฟิลเตอร์สถานะ
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = filters[i];
              final isSel = f == selected;
              return ChoiceChip(
                label: Text(f),
                selected: isSel,
                onSelected: (_) => setState(() => selected = f),
                labelStyle: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
                selectedColor: Colors.white,
                side: BorderSide(
                    color: isSel ? Colors.green : Colors.grey.shade400,
                    width: isSel ? 2 : 1),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),

        const Divider(),

        // รายการออเดอร์ของ "ผู้ใช้คนนี้เท่านั้น"
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                final msg = '${snap.error}';
                // ถ้า index ยัง build อยู่ จะได้ failed-precondition → สลับไปใช้โหมดสำรอง
                if (msg.contains('failed-precondition')) {
                  if (!_fallbackNoOrder) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => _fallbackNoOrder = true);
                    });
                  }
                  return const Center(
                    child: Text('กำลังสร้างดัชนี… แสดงรายการแบบสำรองชั่วคราว'),
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('เกิดข้อผิดพลาด: $msg',
                        textAlign: TextAlign.center),
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = snap.data ?? [];

              // ถ้าเป็นโหมดสำรอง (ไม่ orderBy) → เรียงในแอปแทน (ใหม่ → เก่า)
              if (_fallbackNoOrder) {
                orders = [...orders]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }

              // กรองตามฟิลเตอร์ (หรือแสดงทั้งหมด)
              final list = (selected == 'ทั้งหมด')
                  ? orders
                  : orders
                      .where((o) => o.status == _thToStatus[selected]!)
                      .toList();

              if (list.isEmpty) {
                return const Center(
                    child: Text('ยังไม่มีคำสั่งซื้อในสถานะนี้'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('คำสั่งซื้อ #${o.id}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          OrderStatusChip(_statusToTh(o.status)),
                          const SizedBox(height: 4),
                          Text('สร้างเมื่อ: ${o.createdAt}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      trailing: Text('฿${o.grandTotal.toStringAsFixed(0)}'),

                      // ไปหน้าแสดงรายละเอียด (โหลดจากฐานด้วย orderId)
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => OrderViewPage(orderId: o.id)),
                        );
                      },
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
}
