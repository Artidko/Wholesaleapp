import 'package:flutter/material.dart';
import '../shared/widgets.dart';
import '../../services/auth_service.dart'; // ✅ ใช้ AuthService ใหม่
// (ที่ห่อ FirebaseAuth/Firestore)

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        emailController.text.trim(),
        passwordController.text,
        forceRole: UserRole.user, // ✅ บังคับต้องเป็นบัญชีผู้ใช้ทั่วไป
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home-user');
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
                    const AppLogo(),
                    const SizedBox(height: 24),

                    // 📧 อีเมล
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),

                    // 🔒 รหัสผ่าน + สลับมองเห็น
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
                            : const Text('เข้าสู่ระบบ'),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🔹 สมัครสมาชิก
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pushNamed(context, '/signup'),
                      child: const Text('สมัครสมาชิก'),
                    ),

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
