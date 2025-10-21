// lib/pages/user/tabs/orders_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets.dart'; // ใช้ OrderStatusChip
import '../../../services/order_service.dart';
import '../../../models/order.dart';
import '../../widgets/order_view_page.dart'; // เปิดรายละเอียดด้วย orderId

// 👉 เพิ่มหน้าแผนที่ OSM
import 'order_tracking_map_osm.dart';

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

  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm'); // แสดงวันที่สวยขึ้น
  final _moneyFmt =
      NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบเพื่อดูคำสั่งซื้อ'));
    }

    final stream = OrderService.instance.watchMyOrders(user.uid);

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

        const Divider(height: 16),

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
                    elevation: 0.5,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => OrderViewPage(orderId: o.id)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(Icons.receipt_long),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // หัวข้อ
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('คำสั่งซื้อ #${o.id}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      Text(_moneyFmt.format(o.grandTotal)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // สถานะ
                                  OrderStatusChip(_statusToTh(o.status)),
                                  const SizedBox(height: 4),
                                  // วันเวลา
                                  Text(
                                    'สร้างเมื่อ: ${_dateFmt.format(o.createdAt)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),

                                  // ปุ่มการทำงาน
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  OrderViewPage(orderId: o.id),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 18),
                                        label: const Text('รายละเอียด'),
                                      ),
                                      const SizedBox(width: 8),

                                      // แสดงปุ่ม "ติดตาม" เมื่อสถานะกำลังจัดส่ง
                                      if (o.status == OrderStatus.delivering)
                                        FilledButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    OrderTrackingMapOSM(
                                                        orderId: o.id),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.map_outlined,
                                              size: 18),
                                          label: const Text('ติดตาม'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
}
