import 'package:flutter/material.dart';
import '../../shared/widgets.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final filters = ['ชำระแล้ว', 'กำลังจัดส่ง', 'เสร็จสิ้น', 'ยกเลิก'];
  String selected = 'ชำระแล้ว';

  final orders = List.generate(
    6,
    (i) => {
      'id': 'ORD-2025-00${i + 1}',
      'status': i % 4 == 0
          ? 'ชำระแล้ว'
          : i % 4 == 1
          ? 'กำลังจัดส่ง'
          : i % 4 == 2
          ? 'เสร็จสิ้น'
          : 'ยกเลิก',
      'total': 1200 + i * 100,
      'track': 'TH12345${i}XYZ',
      'timeline': [
        'รับออเดอร์',
        'ชำระเงินสำเร็จ',
        'กำลังจัดส่ง',
        'จัดส่งสำเร็จ',
      ],
    },
  );

  @override
  Widget build(BuildContext context) {
    final list = orders.where((o) => o['status'] == selected).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        // ฟิลเตอร์ด้านบน
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

                // ✅ ฟอนต์ดำ พื้นหลังขาว
                labelStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                selectedColor: Colors.white,

                // ✅ กรอบเขียวเมื่อเลือก, เทาเมื่อไม่เลือก
                side: BorderSide(
                  color: isSel ? Colors.green : Colors.grey.shade400,
                  width: isSel ? 2 : 1,
                ),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const Divider(),

        // รายการคำสั่งซื้อ
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(o['id'] as String),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      OrderStatusChip(o['status'] as String),
                      const SizedBox(height: 4),
                      Text('เลขพัสดุ: ${o['track']}'),
                    ],
                  ),
                  trailing: Text('฿${(o['total'] as num).toStringAsFixed(0)}'),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => OrderDetailSheet(order: o),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class OrderDetailSheet extends StatelessWidget {
  final Map<String, Object?> order;
  const OrderDetailSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final timeline = (order['timeline'] as List).cast<String>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order['id'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          OrderStatusChip(order['status'] as String),
          const SizedBox(height: 8),
          Text('เลขพัสดุ: ${order['track']}'),
          const SizedBox(height: 12),
          Text(
            'สถานะการจัดส่ง (ไทม์ไลน์)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...timeline.map(
            (t) => Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(t)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
