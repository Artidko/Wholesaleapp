import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.storefront, size: size),
        const SizedBox(width: 8),
        Text('Wholesale', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// TextFormField แบบยืดหยุ่น (อัปเดต)
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;

  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.focusNode,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: obscure ? 1 : maxLines,
      minLines: obscure ? 1 : minLines,
      autofillHints: autofillHints,
      validator: errorText != null ? (_) => errorText : validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const PrimaryButton({super.key, required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, child: Text(text));
  }
}

/// ชิปสถานะออเดอร์
class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip(this.status, {super.key});

  Color _bg(BuildContext ctx) {
    switch (status) {
      case 'ชำระแล้ว':
        return Colors.green.shade600;
      case 'กำลังจัดส่ง':
        return Colors.blue.shade600;
      case 'เสร็จสิ้น':
        return Colors.teal.shade600;
      case 'ยกเลิก':
        return Colors.red.shade600;
      default:
        return Theme.of(ctx).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: _bg(context),
    );
  }
}
