import 'package:flutter/material.dart';

class AdminFinanceTab extends StatefulWidget {
  const AdminFinanceTab({super.key});

  @override
  State<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends State<AdminFinanceTab> {
  final ranges = ['วันนี้', '7 วัน', '30 วัน', 'YTD'];
  String selected = '30 วัน';

  final tx = List.generate(
    12,
    (i) => {
      'type': i % 3 == 0 ? 'รายจ่าย' : 'รายรับ',
      'desc': i % 3 == 0 ? 'ค่าขนส่ง' : 'รับชำระคำสั่งซื้อ',
      'amount': i % 3 == 0 ? -(120 + i * 10) : (600 + i * 30),
      'time': DateTime.now().subtract(Duration(days: i)),
    },
  );

  @override
  Widget build(BuildContext context) {
    final total = tx.fold<num>(0, (sum, e) => sum + (e['amount'] as num));

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ranges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = ranges[i];
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('สรุปสุทธิช่วงที่เลือก'),
              subtitle: Text('รวมรายรับ–รายจ่าย'),
              trailing: Text(
                '${total >= 0 ? '+' : ''}฿${total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: total >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tx.length,
            itemBuilder: (_, i) {
              final t = tx[i];
              final amt = t['amount'] as num;
              return Card(
                child: ListTile(
                  leading: Icon(
                    amt >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: amt >= 0 ? Colors.green : Colors.red,
                  ),
                  title: Text('${t['type']} — ฿${amt.toStringAsFixed(0)}'),
                  subtitle: Text(
                    '${t['desc']} • ${(t['time'] as DateTime).toLocal()}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      /* TODO: export, edit, delete */
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'export',
                        child: Text('Export รายการนี้'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('แก้ไขรายการ')),
                      PopupMenuItem(value: 'delete', child: Text('ลบรายการ')),
                    ],
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
