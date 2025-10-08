import 'package:flutter/material.dart';
import '../shared/widgets.dart';
import '../../services/auth_service.dart'; // ✅ ใช้ AuthService ใหม่ (Firebase)

class LoginAdminPage extends StatefulWidget {
  const LoginAdminPage({super.key});

  @override
  State<LoginAdminPage> createState() => _LoginAdminPageState();
}

class _LoginAdminPageState extends State<LoginAdminPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _loading = false;

  String? _validateEmail(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return 'กรุณากรอกอีเมล';
    final r = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!r.hasMatch(text)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'กรุณากรอกรหัสผ่าน';
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        emailController.text.trim(),
        passwordController.text,
        forceRole: UserRole.admin, // ✅ ต้องเป็นแอดมินเท่านั้น
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home-admin');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AppLogo(), // โลโก้ + ชื่อระบบ
                    const SizedBox(height: 24),

                    // 📧 Email
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(labelText: 'Email (Admin)'),
                      validator: _validateEmail,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),

                    // 🔒 Password + eye toggle
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                      enabled: !_loading,
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('เข้าสู่ระบบ (Admin)'),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🔙 กลับไปเลือกประเภท
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pushReplacementNamed(
                                context,
                                '/choose-login',
                              ),
                      child: const Text('กลับไปเลือกประเภท'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
