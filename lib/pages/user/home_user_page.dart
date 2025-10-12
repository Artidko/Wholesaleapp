import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'tabs/cart_tab.dart'; // import CartTab ใหม่

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _index = 0;

  final _pages = const [
    UserHomeTab(),
    CatalogTab(),
    CartTab(), // ใช้ CartTab ใหม่
    OrdersTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('ยินดีต้อนรับ${user != null ? ', ${user.name}' : ''}'),
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// ---------------------- HOME ----------------------
class UserHomeTab extends StatelessWidget {
  const UserHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            hintText: 'ค้นหาสินค้า...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        Text('แนะนำสำหรับคุณ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(
          4,
          (i) => Card(
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: Text('สินค้าแนะนำ #${i + 1}'),
              trailing: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add_shopping_cart),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------- CATALOG ----------------------
class CatalogTab extends StatelessWidget {
  const CatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = ['ทั้งหมด', 'อาหารแห้ง', 'เครื่องดื่ม', 'ของใช้', 'อื่นๆ'];
    String selected = cats.first;

    return StatefulBuilder(
      builder: (ctx, setSt) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า/แบรนด์...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
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
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: cats.length,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              itemBuilder: (_, i) => Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text('สินค้า $selected #${i + 1}'),
                  subtitle: const Text('บรรจุ: ลัง / โหล • สต็อก: พร้อมส่ง'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------- ORDERS ----------------------
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    // mock orders
    final orders = List.generate(
      3,
      (i) => {
        'id': 'ORD-2025-00${i + 1}',
        'status': 'ชำระแล้ว',
        'total': 1200 + i * 100,
      },
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: orders
          .map(
            (o) => Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(o['id'] as String),
                trailing: Text('฿${(o['total'] as num).toStringAsFixed(0)}'),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// ---------------------- SETTINGS ----------------------
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user?.name ?? 'ผู้ใช้'),
          subtitle: Text(user?.email ?? ''),
        ),
        const Divider(),
        const _SectionHeader('ข้อมูลบัญชี'),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('ชื่อผู้ใช้ / ผู้ติดต่อ'),
          subtitle: const Text('แก้ไขชื่อที่แสดง'),
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email_outlined),
          title: const Text('อีเมล'),
          subtitle: Text(user?.email ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('เปลี่ยนรหัสผ่าน'),
        ),
        const Divider(),
        const _SectionHeader('ที่อยู่จัดส่ง'),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('ที่อยู่ทั้งหมด'),
          subtitle: const Text('เพิ่ม/แก้ไข/ตั้งค่า default'),
        ),
        const Divider(),
        const _SectionHeader('การชำระเงิน'),
        ListTile(
          leading: const Icon(Icons.credit_card),
          title: const Text('วิธีชำระเงิน'),
          subtitle: const Text('บัตร/โอน/เครดิตวางบิล'),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('ตั้งค่าเอกสารใบเสร็จ'),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () async {
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login/user',
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
