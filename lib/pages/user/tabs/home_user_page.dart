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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      UserHomeTab(onGoToCatalog: _goToCatalog),
      const CatalogTab(),
      const CartTab(),
      const OrdersTab(),
      const SettingsTab(),
    ];
  }

  void _goToCatalog({String? initialQuery, String? category}) {
    setState(() => _index = 1);
    // ต่อให้ไม่มีช่องค้นหา ก็ยังคงสลับไปแท็บแคตตาล็อกได้
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final totalQty = context.watch<CartProvider>().totalQty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(
                (user?.name.isNotEmpty == true ? user!.name[0] : 'U')
                    .toUpperCase(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user != null && user.name.isNotEmpty
                    ? 'สวัสดี, ${user.name}'
                    : 'สวัสดี',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

/// ---------------------- HOME (มินิมอล+แต่งน้อยๆ, ไม่มีค้นหา) ----------------------
class UserHomeTab extends StatefulWidget {
  final void Function({String? initialQuery, String? category}) onGoToCatalog;
  const UserHomeTab({super.key, required this.onGoToCatalog});

  @override
  State<UserHomeTab> createState() => _UserHomeTabState();
}

class _UserHomeTabState extends State<UserHomeTab> {
  final _quickCats = const [
    'เครื่องดื่ม',
    'อาหารแห้ง',
    'ของใช้',
    'ขนม',
    'อื่น ๆ'
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // แถบข้อมูลส่ง + ปุ่มไปแคตตาล็อก
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'เลือก/เปลี่ยนที่อยู่ในขั้นตอน Checkout',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => widget.onGoToCatalog(),
              icon: const Icon(Icons.storefront, size: 18),
              label: const Text('ดูสินค้า'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 24),

        // หมวดหมู่ — ปุ่มขอบเส้นบางๆ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickCats
              .map(
                (c) => OutlinedButton(
                  onPressed: () => widget.onGoToCatalog(category: c),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outlineVariant),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        const Divider(height: 28),

        // สินค้าใหม่ล่าสุด
        _SectionHeader(
          icon: Icons.fiber_new,
          title: 'สินค้าใหม่ล่าสุด',
          onSeeAll: () => widget.onGoToCatalog(),
        ),
        const SizedBox(height: 6),

        StreamBuilder<List<Product>>(
          stream: ProductService.instance.watchAll(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorText('เกิดข้อผิดพลาด: ${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final items = (snap.data ?? []).take(8).toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('ยังไม่มีสินค้า'),
              );
            }
            return Column(
              children: items
                  .map(
                    (p) => _ProductCard(
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
                    ),
                  )
                  .toList(),
            );
          },
        ),

        const SizedBox(height: 16),
        _SectionHeader(
          icon: Icons.local_drink_outlined,
          title: 'เครื่องดื่ม แนะนำ',
          onSeeAll: () => widget.onGoToCatalog(category: 'เครื่องดื่ม'),
        ),
        const SizedBox(height: 6),

        SizedBox(
          height: 130,
          child: StreamBuilder<List<Product>>(
            stream: ProductService.instance.watchByCategory('เครื่องดื่ม'),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }
              final drinks = (snap.data ?? []).take(10).toList();
              if (drinks.isEmpty) {
                return const Center(child: Text('ยังไม่มีรายการในหมวดนี้'));
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: drinks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final p = drinks[i];
                  return _MiniChipCard(
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

/// ---- ส่วนประกอบ UI ----

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader(
      {required this.icon, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('ดูทั้งหมด')),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(url: product.imageUrl, size: 64, radius: 8),
              const SizedBox(width: 12),
              Expanded(
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('ใส่ตะกร้า'),
                  onPressed: onAdd,
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

class _MiniChipCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  const _MiniChipCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Thumb(url: product.imageUrl, size: 56, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onAdd,
            tooltip: 'เพิ่มลงตะกร้า',
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const _Thumb({required this.url, this.size = 56, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
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

class _ErrorText extends StatelessWidget {
  final String msg;
  const _ErrorText(this.msg);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        msg,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
