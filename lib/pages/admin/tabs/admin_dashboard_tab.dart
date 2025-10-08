import 'package:flutter/material.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final ranges = ['วันนี้', '7 วัน', '30 วัน', 'YTD'];
  String selected = '7 วัน';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filter Ranges
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ranges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final r = ranges[i];
              final sel = r == selected;
              return ChoiceChip(
                label: Text(r),
                selected: sel,
                onSelected: (_) => setState(() => selected = r),
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
        const SizedBox(height: 12),

        // KPI Cards
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _KpiCard(title: 'ยอดขายรวม', value: '฿128,900'),
            _KpiCard(title: 'คำสั่งซื้อ', value: '86'),
            _KpiCard(title: 'ลูกค้าใหม่', value: '23'),
            _KpiCard(title: 'คืนสินค้า', value: '2'),
          ],
        ),

        const SizedBox(height: 16),
        // รายงานย่อ (mock)
        Card(
          child: ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('ยอดขายรวมตามวัน (สรุป)'),
            subtitle: const Text(
              'แนวโน้มยอดขายกำลังเติบโต +8% จากช่วงก่อนหน้า',
            ),
            trailing: TextButton(
              onPressed: () {},
              child: const Text('ดูรายละเอียด'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('คำสั่งซื้อค้างจัดส่ง'),
            subtitle: const Text('8 ออเดอร์ต้องจัดการภายในวันนี้'),
            trailing: TextButton(
              onPressed: () {},
              child: const Text('ไปจัดการ'),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  const _KpiCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
