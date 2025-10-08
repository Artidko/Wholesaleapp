import 'package:flutter/material.dart';

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  final filters = ['ทั้งหมด', 'ชำระแล้ว', 'กำลังจัดส่ง', 'เสร็จสิ้น', 'ยกเลิก'];
  String selected = 'ทั้งหมด';

  final orders = List.generate(
    12,
    (i) => {
      'id': 'ORD-2025-1${i.toString().padLeft(2, '0')}',
      'customer': 'คุณลูกค้า #$i',
      'status': ['ชำระแล้ว', 'กำลังจัดส่ง', 'เสร็จสิ้น', 'ยกเลิก'][i % 4],
      'total': 1000 + i * 70,
      'track': 'THX${i}XYZ',
    },
  );

  @override
  Widget build(BuildContext context) {
    final list = selected == 'ทั้งหมด'
        ? orders
        : orders.where((o) => o['status'] == selected).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        // Filter
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
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                selectedColor: Colors.white,
                side: BorderSide(
                  color: sel ? Colors.green : Colors.grey.shade400,
                  width: sel ? 2 : 1,
                ),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const Divider(),
        // Orders
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('${o['id']} • ${o['customer']}'),
                  subtitle: Text('${o['status']} • เลขพัสดุ: ${o['track']}'),
                  trailing: Text('฿${(o['total'] as num).toStringAsFixed(0)}'),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => _AdminOrderDetail(order: o),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminOrderDetail extends StatelessWidget {
  final Map<String, Object?> order;
  const _AdminOrderDetail({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order['id']}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('ลูกค้า: ${order['customer']}'),
          Text('สถานะ: ${order['status']}'),
          Text('เลขพัสดุ: ${order['track']}'),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () {
                  /* TODO: เปลี่ยนสถานะ */
                },
                icon: const Icon(Icons.done_all),
                label: const Text('ทำเครื่องหมายสำเร็จ'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  /* TODO: แก้ไข/ยกเลิก */
                },
                icon: const Icon(Icons.edit),
                label: const Text('แก้ไข'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
