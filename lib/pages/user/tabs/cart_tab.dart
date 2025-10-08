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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cart.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('ตะกร้าว่าง')),
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
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
                  title: Text(p.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('฿${p.price.toStringAsFixed(2)} / หน่วย'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                context.read<CartProvider>().decrement(p.id),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${line.qty}'),
                          IconButton(
                            onPressed: () =>
                                context.read<CartProvider>().increment(p.id),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '฿${line.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        if (!cart.isEmpty)
          ListTile(
            title: const Text('ยอดรวม'),
            trailing: Text(
              '฿${cart.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: cart.isEmpty
              ? null
              : () async {
                  // ✅ ไปหน้า CheckoutPage
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutPage()),
                  );

                  // ถ้าเช็คเอาต์สำเร็จ (เราส่ง address+payment กลับมาจาก CheckoutPage)
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
