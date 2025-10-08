import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/product_service.dart';

class CatalogTab extends StatelessWidget {
  const CatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = ['ทั้งหมด', 'อาหารแห้ง', 'เครื่องดื่ม', 'ของใช้', 'อื่นๆ'];
    String selected = cats.first;
    String query = '';

    return StatefulBuilder(
      builder: (ctx, setSt) => Column(
        children: [
          // ค้นหา
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ค้นหาสินค้า/แบรนด์...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setSt(() => query = v.trim()),
            ),
          ),

          // ปุ่มช่วยดีบัก / ยิงสินค้าทดสอบ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มสินค้าเดโม่'),
                  onPressed: () async {
                    await ProductService.instance.seedDemo();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('เพิ่มสินค้าทดสอบแล้ว')),
                      );
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'รีโหลด',
                  onPressed: () => setSt(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          // หมวดหมู่จริง (ชื่อใน Firestore ต้องตรงกับชิป)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final c = cats[i];
                final sel = c == selected;
                return ChoiceChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setSt(() => selected = c),
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: cats.length,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ สินค้าจาก Firestore (กรองตามหมวดตั้งแต่ฝั่งเซิร์ฟเวอร์)
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: ProductService.instance.watchByCategory(selected),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(
                    message: 'เกิดข้อผิดพลาด: ${snap.error}',
                    onRetry: () => setSt(() {}),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snap.data ?? [];

                // กรองด้วยข้อความค้นหา (ชื่อ/sku) ฝั่งแอป
                if (query.isNotEmpty) {
                  final q = query.toLowerCase();
                  items = items
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(q) ||
                            (p.sku ?? '').toLowerCase().contains(q),
                      )
                      .toList();
                }

                if (items.isEmpty) {
                  return _EmptyState(
                    title: selected == 'ทั้งหมด'
                        ? (query.isEmpty
                              ? 'ยังไม่มีสินค้า'
                              : 'ไม่พบสินค้าที่ตรงกับการค้นหา')
                        : 'ไม่พบสินค้าในหมวด "$selected"',
                    onRetry: () => setSt(() => query = ''),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setSt(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final product = items[i];

                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: product.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: product.imageUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.broken_image),
                                  )
                                : const Icon(Icons.inventory_2),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '฿${product.price.toStringAsFixed(2)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              context.read<CartProvider>().add(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'เพิ่ม "${product.name}" เข้าตะกร้าแล้ว',
                                  ),
                                  duration: const Duration(milliseconds: 900),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- UI States ----------------

class _EmptyState extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;
  const _EmptyState({required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
