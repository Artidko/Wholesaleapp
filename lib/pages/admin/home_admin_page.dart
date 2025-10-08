import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

// นำเข้าแท็บย่อย
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_inventory_tab.dart';
import 'tabs/admin_orders_tab.dart';
import 'tabs/admin_finance_tab.dart';
import 'tabs/admin_profile_tab.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _index = 0;

  late final List<Widget> _pages = const [
    AdminDashboardTab(),
    AdminInventoryTab(),
    AdminOrdersTab(),
    AdminFinanceTab(),
    AdminProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('Admin — ${user?.name ?? 'ผู้ดูแลระบบ'}')),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'คลังสินค้า',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'คำสั่งซื้อ',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'การเงิน',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
