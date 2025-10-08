import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../services/auth_service.dart';
import '../../../services/product_service.dart';
import '../../../providers/cart_provider.dart';
import '../../../models/product.dart';

// Tabs
import 'catalog_tab.dart';
import 'cart_tab.dart';
import 'orders_tab.dart';
import 'settings_tab.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _index = 0;

  late final List<Widget> _pages = const [
    UserHomeTab(),
    CatalogTab(),
    CartTab(),
    OrdersTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final totalQty = context.watch<CartProvider>().totalQty;

    return Scaffold(
      appBar: AppBar(
        title: Text('ยินดีต้อนรับ${user != null ? ', ${user.name}' : ''}'),
      ),
      body: IndexedStack(index: _index, children: _pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Catalog',
          ),
          _cartDestination(totalQty),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  NavigationDestination _cartDestination(int totalQty) {
    Widget baseIcon = const Icon(Icons.shopping_cart_outlined);
    Widget baseSelectedIcon = const Icon(Icons.shopping_cart);

    Widget withBadge(Widget child) {
      if (totalQty <= 0) return child;
      try {
        return Badge(label: Text('$totalQty'), child: child);
      } catch (_) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalQty',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        );
      }
    }

    return NavigationDestination(
      icon: withBadge(baseIcon),
      selectedIcon: withBadge(baseSelectedIcon),
      label: 'Cart',
    );
  }
}

/// ---------------------- HOME (สินค้าแนะนำจริง) ----------------------
class UserHomeTab extends StatelessWidget {
  const UserHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'ค้นหาสินค้า...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (q) {
            // ถ้าต้องการให้กดค้นหาแล้วพาไปหน้า Catalog สามารถใช้ Navigator ไปแท็บ 1 ได้
            // (ปล่อยไว้ก่อนเพื่อความเรียบง่าย)
          },
        ),
        const SizedBox(height: 16),

        // หัวข้อ
        Row(
          children: [
            Text(
              'สินค้าใหม่ล่าสุด',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => DefaultTabController.of(context),
              child: const Text('ดูทั้งหมด'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ✅ ดึงสินค้าจริงจาก Firestore (ล่าสุดก่อน) แสดง 4 ชิ้น
        StreamBuilder<List<Product>>(
          stream: ProductService.instance.watchAll(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = (snap.data ?? []).take(4).toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('ยังไม่มีสินค้า'),
              );
            }

            return Column(
              children: items.map((p) {
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: p.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: p.imageUrl,
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
                    title: Text(p.name),
                    subtitle: Text('฿${p.price.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      tooltip: 'เพิ่มลงตะกร้า',
                      onPressed: () {
                        cart.add(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เพิ่ม "${p.name}" ลงตะกร้าแล้ว'),
                            duration: const Duration(milliseconds: 900),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        // ตัวอย่างแถวหมวด (optional) — โชว์เฉพาะหมวด "เครื่องดื่ม"
        Text('เครื่องดื่ม', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: StreamBuilder<List<Product>>(
            stream: ProductService.instance.watchByCategory('เครื่องดื่ม'),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final drinks = (snap.data ?? []).take(10).toList();
              if (drinks.isEmpty) {
                return const Center(child: Text('ยังไม่มีรายการในหมวดนี้'));
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: drinks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = drinks[i];
                  return _MiniProductCard(
                    product: p,
                    onAdd: () {
                      cart.add(p);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่ม "${p.name}" ลงตะกร้าแล้ว'),
                          duration: const Duration(milliseconds: 900),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
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

/// การ์ดแนวนอนเล็ก ๆ สำหรับแถบหมวด
class _MiniProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  const _MiniProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      )
                    : const Icon(Icons.inventory_2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('฿${product.price.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAdd,
                tooltip: 'เพิ่มลงตะกร้า',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
