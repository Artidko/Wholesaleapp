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

    final cs = Theme.of(context).colorScheme;

    return StatefulBuilder(
      builder: (ctx, setSt) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัวข้อ + ไอคอนเล็ก ๆ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.storefront, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('แคตตาล็อกสินค้า',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'รีโหลด',
                  onPressed: () => setSt(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          // ค้นหา — กล่องเรียบ เงาบาง ๆ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              elevation: 1,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาสินค้า/แบรนด์...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: cs.surface,
                  isDense: true,
                ),
                onChanged: (v) => setSt(() => query = v.trim()),
              ),
            ),
          ),

          const Divider(height: 24),

          // หมวดหมู่: OutlinedButton เส้นจาง มน 8px
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final c = cats[i];
                final sel = c == selected;
                return OutlinedButton(
                  onPressed: () => setSt(() => selected = c),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sel ? cs.primary : cs.onSurface,
                    side: BorderSide(
                      color: sel ? cs.primary : cs.outlineVariant,
                      width: sel ? 1.6 : 1,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(c,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: cats.length,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ เลือกสตรีมตามหมวด: 'ทั้งหมด' -> watchAll(), อื่น ๆ -> watchByCategory
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: selected == 'ทั้งหมด'
                  ? ProductService.instance.watchAll()
                  : ProductService.instance.watchByCategory(selected),
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

                // กรองค้นหา (ชื่อ/sku)
                if (query.isNotEmpty) {
                  final q = query.toLowerCase();
                  items = items
                      .where((p) =>
                          p.name.toLowerCase().contains(q) ||
                          (p.sku ?? '').toLowerCase().contains(q))
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final product = items[i];
                      return _ProductCardMinimal(product: product);
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

/// ---- การ์ดสินค้าแบบคลีน ดูมือทำ ----
class _ProductCardMinimal extends StatelessWidget {
  final Product product;
  const _ProductCardMinimal({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {}, // เผื่อไปหน้า detail ภายหลัง
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(url: product.imageUrl, size: 64, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '฿${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: cs.primary.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((product.sku ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${product.sku}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('ใส่ตะกร้า'),
                  onPressed: () {
                    context.read<CartProvider>().add(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เพิ่ม "${product.name}" เข้าตะกร้าแล้ว'),
                        duration: const Duration(milliseconds: 900),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---- รูปสินค้าโค้ง 8px + Placeholder เรียบ ๆ ----
class _Thumb extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const _Thumb({required this.url, this.size = 56, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Icon(Icons.image, size: 20),
    );
    if (url.isEmpty) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => ph,
        errorWidget: (_, __, ___) => ph,
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: cs.outline)),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
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
