import 'package:flutter/material.dart';
import '../shared/widgets.dart';

class ChooseLoginPage extends StatelessWidget {
  const ChooseLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(),
                const SizedBox(height: 28),
                Text(
                  'เลือกประเภทการเข้าสู่ระบบ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // ปุ่ม User
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login-user'),
                    icon: const Icon(Icons.person),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('เข้าสู่ระบบสำหรับ User'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ปุ่ม Admin
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login-admin'),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('เข้าสู่ระบบสำหรับ Admin'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ลิงก์สมัครสมาชิก
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ยังไม่มีบัญชี?'),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text('สมัครสมาชิก'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ป้ายกำกับเล็กๆ
                Text(
                  'Wholesale & Smart Delivery',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
