import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminInventoryTab extends StatefulWidget {
  const AdminInventoryTab({super.key});

  @override
  State<AdminInventoryTab> createState() => _AdminInventoryTabState();
}

class _AdminInventoryTabState extends State<AdminInventoryTab> {
  final cats = const ['ทั้งหมด', 'อาหารแห้ง', 'เครื่องดื่ม', 'ของใช้', 'อื่นๆ'];
  String selected = 'ทั้งหมด';

  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// คิวรีหลัก: กรองเฉพาะหมวด (ถ้าเลือก) แล้วเรียงตาม updatedAt ใหม่สุดก่อน
  Query<Map<String, dynamic>> _baseQuery() {
    var q = FirebaseFirestore.instance
        .collection('products')
        .orderBy('updatedAt', descending: true);

    if (selected != 'ทั้งหมด') {
      q = q.where('category', isEqualTo: selected);
    }
    return q;
  }

  /// ปรับสต็อกแบบ transaction (+/- diff)
  Future<void> _adjustStock(String productId, int diff) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('products').doc(productId);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('ไม่พบสินค้า');
      final data = snap.data() as Map<String, dynamic>;
      final current = (data['stock'] ?? 0) as int;
      final next = current + diff;
      if (next < 0) throw Exception('สต็อกติดลบไม่ได้');
      tx.update(ref, {
        'stock': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// ตั้งค่าสต็อกเป็นตัวเลขใหม่
  Future<void> _setStock(String productId, int newStock) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<int?> _askInt({
    required String title,
    required int initial,
    String hint = 'จำนวน (≥ 0)',
  }) async {
    final ctl = TextEditingController(text: '$initial');
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctl.text.trim());
              if (n == null || n < 0) return _toast('กรุณากรอกตัวเลข ≥ 0');
              Navigator.pop(context, n);
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Future<int?> _askSignedInt({
    required String title,
    String hint = 'จำนวน (ใส่ลบได้ เช่น -3)',
  }) async {
    final ctl = TextEditingController(text: '0');
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctl.text.trim());
              if (n == null) return _toast('กรุณากรอกตัวเลข');
              Navigator.pop(context, n);
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topBar = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อสินค้า/รหัส SKU...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_searchCtl.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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
        const Divider(height: 16),
      ],
    );

    return Column(
      children: [
        topBar,
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _baseQuery().snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
              }
              final docs = snap.data?.docs ?? [];

              final items = docs.map((d) {
                final m = d.data();
                return _InvItem(
                  id: d.id,
                  name: (m['name'] ?? '') as String,
                  sku: (m['sku'] ?? '') as String,
                  stock: (m['stock'] ?? 0) as int,
                  unit: (m['unit'] ?? '') as String,
                  imageUrl: (m['imageUrl'] ?? '') as String,
                  category: (m['category'] ?? '') as String,
                );
              }).toList();

              // ค้นหา client-side
              final kw = _searchCtl.text.trim().toLowerCase();
              final filtered = kw.isEmpty
                  ? items
                  : items
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(kw) ||
                            p.sku.toLowerCase().contains(kw),
                      )
                      .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('ไม่พบสินค้า'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return Card(
                    child: ListTile(
                      leading: _Thumb(url: p.imageUrl),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'SKU: ${p.sku} • คงเหลือ: ${p.stock}${p.unit.isNotEmpty ? ' ${p.unit}' : ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            if (v == 'receive') {
                              final n = await _askInt(
                                title: 'รับสินค้าเข้า: ${p.name}',
                                initial: 1,
                                hint: 'จำนวนรับเข้า (≥ 0)',
                              );
                              if (n != null && n > 0) {
                                await _adjustStock(p.id, n);
                                _toast('รับเข้า +$n สำเร็จ');
                              }
                            } else if (v == 'adjust') {
                              final n = await _askSignedInt(
                                title: 'ปรับ/ตัดสต็อก: ${p.name}',
                                hint: 'จำนวน (ใส่ลบได้ เช่น -3)',
                              );
                              if (n != null && n != 0) {
                                await _adjustStock(p.id, n);
                                _toast(
                                    'ปรับสต็อก ${n > 0 ? '+$n' : '$n'} สำเร็จ');
                              }
                            } else if (v == 'set') {
                              final newVal = await _askInt(
                                title: 'ตั้งค่า Stock: ${p.name}',
                                initial: p.stock,
                              );
                              if (newVal != null) {
                                await _setStock(p.id, newVal);
                                _toast('ตั้งค่าเป็น $newVal สำเร็จ');
                              }
                            }
                          } catch (e) {
                            _toast(e.toString());
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'receive',
                              child: Text('รับสินค้าเข้า (+)')),
                          PopupMenuItem(
                              value: 'adjust',
                              child: Text('ปรับ/ตัดสต็อก (+/-)')),
                          PopupMenuItem(
                              value: 'set', child: Text('ตั้งค่าสต็อก...')),
                        ],
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

class _InvItem {
  final String id;
  final String name;
  final String sku;
  final int stock;
  final String unit;
  final String imageUrl;
  final String category;
  const _InvItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.stock,
    required this.unit,
    required this.imageUrl,
    required this.category,
  });
}

class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});
  @override
  Widget build(BuildContext context) {
    const w = 44.0;
    if (url.isEmpty) {
      return Container(
        width: w,
        height: w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, width: w, height: w, fit: BoxFit.cover),
    );
  }
}
