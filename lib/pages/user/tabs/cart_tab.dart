import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/cart_provider.dart';
import 'checkout_page.dart'; // ✅ ใช้หน้าเช็คเอาต์ใหม่

class CartTab extends StatefulWidget {
  const CartTab({super.key});
  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // ---- Header: ไอคอนเล็ก + ระยะหายใจ ----
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 8),
          Text(
            'ตะกร้าสินค้า',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        header,
        if (cart.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Material(
              elevation: 1, // เงาบาง ๆ ให้มีเลเยอร์
              shadowColor: Colors.black12,
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(child: Text('ตะกร้าว่าง')),
              ),
            ),
          )
        else
          ...cart.lines.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            final p = line.product;

            return Dismissible(
              key: ValueKey('cart_${p.id}_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => context.read<CartProvider>().remove(p.id),
              child: Card(
                elevation: 0, // ไม่ใส่เงาหนัก
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // การ์ด 10px
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8), // รูป 8px โค้ง
                      child: (p.imageUrl.isNotEmpty)
                          ? Image.network(
                              p.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgFallback(),
                            )
                          : _imgFallback(),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        // ราคา/รวมต่อบรรทัดเป็นชิพโทน primary จาง ๆ
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '฿${line.lineTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: primary.withOpacity(.85),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('฿${p.price.toStringAsFixed(2)} / หน่วย',
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _qtyBtn(
                                context,
                                icon: Icons.remove,
                                onTap: () => context
                                    .read<CartProvider>()
                                    .decrement(p.id),
                              ),
                              const SizedBox(width: 8),
                              Text('${line.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              _qtyBtn(
                                context,
                                icon: Icons.add,
                                onTap: () => context
                                    .read<CartProvider>()
                                    .increment(p.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ไม่ใช้ trailing หนัก ๆ เพื่อความบาลานซ์
                  ),
                ),
              ),
            );
          }),
        if (!cart.isEmpty) ...[
          const SizedBox(height: 8),
          // แถบสรุปยอดแบบ Material elevation 1
          Material(
            elevation: 1,
            shadowColor: Colors.black12,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long),
              ),
              title: const Text('ยอดรวม'),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '฿${cart.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: primary.withOpacity(.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutPage()),
              );
              if (result != null && context.mounted) {
                context.read<CartProvider>().clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('สั่งซื้อสำเร็จและเคลียร์ตะกร้าแล้ว'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.payment),
            label: const Text('ไปชำระเงิน / เลือกที่อยู่'),
          ),
        ],
      ],
    );
  }

  // ปุ่มจำนวนแบบ OutlinedButton มน 8px เส้นจาง
  Widget _qtyBtn(BuildContext context,
      {required IconData icon, required VoidCallback onTap}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      onPressed: onTap,
      child: Icon(icon, size: 18),
    );
  }

  Widget _imgFallback() => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
}
