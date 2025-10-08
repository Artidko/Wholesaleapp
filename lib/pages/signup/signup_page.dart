import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../shared/widgets.dart'; // AppLogo

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  final _cpwCtl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _pwCtl.dispose();
    _cpwCtl.dispose();
    super.dispose();
  }

  double _passwordStrength(String v) {
    if (v.isEmpty) return 0.0;
    double score = 0;
    if (v.length >= 6) score += 0.25;
    if (v.length >= 10) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(v)) score += 0.2;
    if (RegExp(r'[a-z]').hasMatch(v)) score += 0.2;
    if (RegExp(r'\d').hasMatch(v)) score += 0.1;
    if (RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]{};:\"",.<>\/?\\|`~]').hasMatch(v)) {
      score += 0.1;
    }
    return score.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUpWithEmail(
        email: _emailCtl.text.trim(),
        password: _pwCtl.text,
        fullName: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ')),
      );
      Navigator.pushReplacementNamed(context, '/choose-login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = _passwordStrength(_pwCtl.text);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameCtl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อ-นามสกุล',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'กรุณากรอกชื่อ-นามสกุล'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        }
                        final ok = RegExp(
                          r'^[^@]+@[^@]+\.[^@]+',
                        ).hasMatch(v.trim());
                        if (!ok) return 'รูปแบบอีเมลไม่ถูกต้อง';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทร',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'กรุณากรอกเบอร์โทร';
                        }
                        if (v.trim().length < 9) return 'เบอร์โทรไม่ถูกต้อง';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _pwCtl,
                      obscureText: _obscure1,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure1 = !_obscure1),
                          icon: Icon(
                            _obscure1 ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        }
                        if (v.length < 6) {
                          return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    LinearProgressIndicator(
                      value: strength,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        strength < 0.35
                            ? cs.error
                            : (strength < 0.7 ? cs.tertiary : cs.primary),
                      ),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cpwCtl,
                      obscureText: _obscure2,
                      decoration: InputDecoration(
                        labelText: 'ยืนยันรหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure2 = !_obscure2),
                          icon: Icon(
                            _obscure2 ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v != _pwCtl.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add),
                        label: const Text('สมัครสมาชิก'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('มีบัญชีแล้ว?'),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/choose-login',
                          ),
                          child: const Text('เข้าสู่ระบบ'),
                        ),
                      ],
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
