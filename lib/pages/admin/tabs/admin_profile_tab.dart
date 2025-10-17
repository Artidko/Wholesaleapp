import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';

class AdminProfileTab extends StatelessWidget {
  const AdminProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final u = AuthService.instance.currentUser;

    // ---- Header (ไอคอนเล็ก + ช่องไฟ) ----
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.settings_suggest,
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 8),
          Text('ตั้งค่าผู้ดูแล',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
              )),
        ],
      ),
    );

    // ---- การ์ดโปรไฟล์ (Material elevation 1, โค้ง 10px) ----
    final profileCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 1,
        shadowColor: Colors.black12,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(8), // 8px โค้ง
            ),
            child: const Icon(Icons.person, size: 28),
          ),
          title: Text(u?.name.isNotEmpty == true ? u!.name : 'ผู้ดูแลระบบ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Row(
            children: [
              if ((u?.email ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.06), // primary จางๆ
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    u!.email,
                    style: TextStyle(
                      color: primary.withOpacity(.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // ---- กลุ่มเมนูบัญชี (Material elevation 1) ----
    final accountGroup = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.admin_panel_settings, text: 'บัญชีผู้ดูแล'),
          const SizedBox(height: 6),
          Material(
            elevation: 1,
            shadowColor: Colors.black12,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('เปลี่ยนรหัสผ่าน'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openChangePasswordSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ---- ปุ่มออกจากระบบ (OutlinedButton โค้ง 8px เส้นจาง) ----
    final logoutBtn = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
          foregroundColor: Colors.black87,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () async {
          await AuthService.instance.logout();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login/admin',
              (_) => false,
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('ออกจากระบบ'),
      ),
    );

    return ListView(
      children: [
        header,
        profileCard,
        accountGroup,
        logoutBtn,
      ],
    );
  }

  void _openChangePasswordSheet(BuildContext context) {
    final theme = Theme.of(context);
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true, obscureNew = true, obscureConfirm = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                    icon: Icons.lock_outline, text: 'เปลี่ยนรหัสผ่าน (Admin)'),
                const SizedBox(height: 6),
                Text(
                  'ป้อนรหัสผ่านเดิมและรหัสใหม่',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: oldCtrl,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่านเดิม',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureOld ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setSt(() => obscureOld = !obscureOld),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'กรุณากรอกรหัสผ่านเดิม' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setSt(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                    if (v.length < 6)
                      return 'รหัสผ่านควรยาวอย่างน้อย 6 ตัวอักษร';
                    if (v == oldCtrl.text)
                      return 'รหัสผ่านใหม่ต้องต่างจากรหัสเดิม';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'ยืนยันรหัสผ่านใหม่',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setSt(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  validator: (v) =>
                      (v != newCtrl.text) ? 'รหัสผ่านใหม่ไม่ตรงกัน' : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      saving
                          ? 'กำลังเปลี่ยนรหัสผ่าน...'
                          : 'ยืนยันการเปลี่ยนรหัสผ่าน',
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSt(() => saving = true);
                            try {
                              await AuthService.instance.changePassword(
                                oldPassword: oldCtrl.text,
                                newPassword: newCtrl.text,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('เปลี่ยนรหัสผ่านสำเร็จ')),
                              );
                            } catch (e) {
                              setSt(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionHeader({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
