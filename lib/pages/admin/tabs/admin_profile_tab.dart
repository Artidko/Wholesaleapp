import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';

class AdminProfileTab extends StatelessWidget {
  const AdminProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.currentUser;
    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(u?.name ?? 'ผู้ดูแลระบบ'),
          subtitle: Text(u?.email ?? ''),
        ),
        const Divider(),
        const _SectionHeader('บัญชีผู้ดูแล'),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('เปลี่ยนรหัสผ่าน'),
          onTap: () {
            _openChangePasswordSheet(context);
          },
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
                  '/login/admin',
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

  void _openChangePasswordSheet(BuildContext context) {
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
              children: [
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('เปลี่ยนรหัสผ่าน (Admin)'),
                  subtitle: Text('ป้อนรหัสผ่านเดิมและรหัสใหม่'),
                ),
                TextFormField(
                  controller: oldCtrl,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่านเดิม',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureOld ? Icons.visibility : Icons.visibility_off,
                      ),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setSt(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                    if (v.length < 6) {
                      return 'รหัสผ่านควรยาวอย่างน้อย 6 ตัวอักษร';
                    }
                    if (v == oldCtrl.text) {
                      return 'รหัสผ่านใหม่ต้องต่างจากรหัสเดิม';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'ยืนยันรหัสผ่านใหม่',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
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
                  child: ElevatedButton.icon(
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
                                  content: Text('เปลี่ยนรหัสผ่านสำเร็จ'),
                                ),
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
