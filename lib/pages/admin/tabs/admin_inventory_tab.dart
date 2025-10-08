import 'package:flutter/material.dart';

class AdminInventoryTab extends StatefulWidget {
  const AdminInventoryTab({super.key});

  @override
  State<AdminInventoryTab> createState() => _AdminInventoryTabState();
}

class _AdminInventoryTabState extends State<AdminInventoryTab> {
  final cats = ['ทั้งหมด', 'อาหารแห้ง', 'เครื่องดื่ม', 'ของใช้', 'อื่นๆ'];
  String selected = 'ทั้งหมด';

  final items = List.generate(
    10,
    (i) => {
      'sku': 'SKU-10$i',
      'name': 'สินค้า #$i',
      'stock': 20 + (i * 3),
      'unit': 'ลัง',
    },
  );

  @override
  Widget build(BuildContext context) {
    final filtered = items; // TODO: filter ตาม selected
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ค้นหาชื่อสินค้า/รหัส SKU...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = cats[i];
              final sel = c == selected;
              return ChoiceChip(
                label: Text(c),
                selected: sel,
                onSelected: (_) => setState(() => selected = c),
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
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = filtered[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text('${p['name']}'),
                  subtitle: Text(
                    'SKU: ${p['sku']} • คงเหลือ: ${p['stock']} ${p['unit']}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      // TODO: show dialogs/flows: receive, adjust, edit
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'receive',
                        child: Text('รับสินค้าเข้า'),
                      ),
                      PopupMenuItem(
                        value: 'adjust',
                        child: Text('ปรับ/ตัดสต็อก'),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('แก้ไขข้อมูลสินค้า'),
                      ),
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
