// lib/pages/user/tabs/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../services/user_settings_service.dart';
import '../../../models/address_item.dart';
import '../../../models/payment_method_item.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  AddressItem? _selectedAddress;
  PaymentMethodItem? _selectedPayment;

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    // seed วิธีชำระเงินแบบ Global (payment_methods) ถ้ายังไม่มี
    UserSettingsService.instance.ensureGlobalPaymentMethods();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('เช็คเอาต์')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 12),
                const Text('กรุณาเข้าสู่ระบบเพื่อทำรายการ'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login-user'),
                  icon: const Icon(Icons.login),
                  label: const Text('ไปหน้าเข้าสู่ระบบ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('เช็คเอาต์')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          _AddressSection(
            onPick: (a) => setState(() => _selectedAddress = a),
            initial: _selectedAddress,
          ),
          const SizedBox(height: 12),
          _PaymentSection(
            onPick: (p) => setState(() => _selectedPayment = p),
            initial: _selectedPayment,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_selectedAddress != null && _selectedPayment != null)
                ? () {
                    Navigator.pop(context, {
                      'address': _selectedAddress,
                      'payment': _selectedPayment,
                    });
                  }
                : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('ยืนยันการสั่งซื้อ'),
          ),
          const SizedBox(height: 12),
          if (_selectedAddress == null || _selectedPayment == null)
            const Text(
              'กรุณาเลือกที่อยู่จัดส่งและวิธีชำระเงิน',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

/* ====================== Address Section ====================== */

class _AddressSection extends StatelessWidget {
  final AddressItem? initial;
  final ValueChanged<AddressItem> onPick;

  const _AddressSection({
    required this.onPick,
    this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<List<AddressItem>>(
        stream: UserSettingsService.instance.addressesStream(),
        initialData: const [],
        builder: (context, snap) {
          if (snap.hasError) {
            return _SectionError('ที่อยู่จัดส่ง', snap.error.toString());
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return _SectionLoading('ที่อยู่จัดส่ง');
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return _SectionEmpty(
              title: 'ที่อยู่จัดส่ง',
              subtitle: 'ยังไม่มีที่อยู่',
              actionText: 'เพิ่มที่อยู่',
              onAction: () => _openPicker(context, items),
            );
          }

          final selected = _pickInitialAddress(items, initial);

          // ✅ แจ้ง parent เฉพาะ "ครั้งแรก" เท่านั้น กันลูป setState
          if (initial == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onPick(selected));
          }

          return _SectionWithCurrent(
            title: 'ที่อยู่จัดส่ง',
            trailingText: 'เปลี่ยน',
            onTrailing: () => _openPicker(context, items),
            child: Text(
              '${selected.fullName}\n'
              '${selected.line1}${selected.line2.isNotEmpty ? '\n${selected.line2}' : ''}\n'
              '${selected.city} ${selected.zip}',
            ),
          );
        },
      ),
    );
  }

  AddressItem _pickInitialAddress(List<AddressItem> items, AddressItem? init) {
    final def = items.where((e) => e.isDefault).toList();
    if (def.isNotEmpty) return def.first;
    if (init != null) return init;
    return items.first;
  }

  Future<void> _openPicker(
      BuildContext context, List<AddressItem> items) async {
    final picked = await showModalBottomSheet<AddressItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _PickerList<AddressItem>(
          title: 'เลือกที่อยู่จัดส่ง',
          items: items,
          itemBuilder: (a) => ListTile(
            leading: Icon(
              a.isDefault ? Icons.star : Icons.location_on_outlined,
            ),
            title: Text(a.fullName),
            subtitle: Text(
              '${a.line1}${a.line2.isNotEmpty ? '\n${a.line2}' : ''}\n${a.city} ${a.zip}',
            ),
            onTap: () => Navigator.pop(ctx, a),
          ),
        );
      },
    );
    if (picked != null) onPick(picked);
  }
}

/* ====================== Payment Section (Global 2 วิธี) ====================== */

class _PaymentSection extends StatelessWidget {
  final PaymentMethodItem? initial;
  final ValueChanged<PaymentMethodItem> onPick;

  const _PaymentSection({
    required this.onPick,
    this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<List<PaymentMethodItem>>(
        stream: UserSettingsService.instance.paymentsStream(),
        initialData: const [],
        builder: (context, snap) {
          if (snap.hasError) {
            return _SectionError('เลือกวิธีการชำระเงิน', snap.error.toString());
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return _SectionLoading('เลือกวิธีการชำระเงิน');
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return _SectionEmpty(
              title: 'เลือกวิธีการชำระเงิน',
              subtitle: 'ยังไม่มีวิธีชำระเงิน',
              actionText: 'เพิ่มวิธีชำระ',
              onAction: () async {
                await UserSettingsService.instance.ensureGlobalPaymentMethods();
              },
            );
          }

          final selected = _pickInitialPayment(items, initial);

          // ✅ แจ้ง parent เฉพาะ "ครั้งแรก" เท่านั้น กันลูป setState
          if (initial == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onPick(selected));
          }

          return _SectionWithCurrent(
            title: 'เลือกวิธีการชำระเงิน',
            trailingText: 'เปลี่ยน',
            onTrailing: () => _openPicker(context, items),
            child: _PaymentSummary(selected: selected),
          );
        },
      ),
    );
  }

  PaymentMethodItem _pickInitialPayment(
      List<PaymentMethodItem> items, PaymentMethodItem? init) {
    // ใช้ค่าที่ผู้ใช้เลือกไว้ก่อน (ถ้ามี)
    if (init != null) {
      final match = items.where((e) => e.id == init.id);
      return match.isNotEmpty ? match.first : init;
    }
    // ถ้าไม่มีค่าเลือก ค่อยใช้ default
    final def = items.where((e) => e.isDefault).toList();
    if (def.isNotEmpty) return def.first;

    // สุดท้ายใช้ตัวแรกในลิสต์
    return items.first;
  }

  Future<void> _openPicker(
      BuildContext context, List<PaymentMethodItem> items) async {
    final picked = await showModalBottomSheet<PaymentMethodItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _PickerList<PaymentMethodItem>(
          title: 'เลือกวิธีชำระเงิน',
          items: items,
          itemBuilder: (p) => ListTile(
            leading: Icon(_iconForType(p.type), color: Colors.blueGrey),
            title: Text(p.label),
            subtitle: _subtitleForType(p),
            trailing: p.isDefault
                ? const Icon(Icons.star, color: Colors.amber)
                : null,
            onTap: () => Navigator.pop(ctx, p),
          ),
        );
      },
    );
    if (picked != null) onPick(picked);
  }

  static IconData _iconForType(PaymentType t) {
    switch (t) {
      case PaymentType.cod:
        return Icons.local_shipping_outlined;
      case PaymentType.promptpay:
        return Icons.qr_code_2;
      default:
        return Icons.payment_outlined;
    }
  }

  static Widget? _subtitleForType(PaymentMethodItem p) {
    switch (p.type) {
      case PaymentType.cod:
        return const Text('ชำระเงินกับพนักงานจัดส่ง');
      case PaymentType.promptpay:
        return Text('พร้อมเพย์: ${p.promptPayId ?? '-'}');
      default:
        return null;
    }
  }
}

class _PaymentSummary extends StatelessWidget {
  final PaymentMethodItem selected;
  const _PaymentSummary({required this.selected});

  @override
  Widget build(BuildContext context) {
    final icon = _PaymentSection._iconForType(selected.type);

    String detail;
    switch (selected.type) {
      case PaymentType.cod:
        detail = 'ชำระเงินกับพนักงานจัดส่ง';
        break;
      case PaymentType.promptpay:
        detail = 'สแกน QR พร้อมเพย์: ${selected.promptPayId ?? '-'}';
        break;
      default:
        detail = '';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Text(selected.label, style: Theme.of(context).textTheme.titleSmall),
            if (selected.isDefault)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.star, size: 18, color: Colors.amber),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
        if (selected.type == PaymentType.promptpay) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('ดู QR พร้อมเพย์'),
              onPressed: () => _showPromptPayQR(context, selected),
            ),
          ),
        ],
      ],
    );
  }

  void _showPromptPayQR(BuildContext context, PaymentMethodItem p) {
    final id = p.promptPayId ?? '';
    final data = 'PROMPTPAY:$id';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('QR พร้อมเพย์'),
                subtitle: Text('ปลายทาง: $id'),
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: data,
                  size: 220,
                  gapless: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                  'หลังสแกน กรุณาส่งหลักฐานการโอน / สลิป หากระบบต้องการ'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/* ====================== Reusable UI pieces ====================== */

class _SectionLoading extends StatelessWidget {
  final String title;
  const _SectionLoading(this.title);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.hourglass_empty),
      title: Text(title),
      subtitle: const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: LinearProgressIndicator(minHeight: 2),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String title;
  final String message;
  const _SectionError(this.title, this.message);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline, color: Colors.red),
      title: Text(title),
      subtitle: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onAction;

  const _SectionEmpty({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: FilledButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.add),
        label: Text(actionText),
      ),
    );
  }
}

class _SectionWithCurrent extends StatelessWidget {
  final String title;
  final String trailingText;
  final VoidCallback onTrailing;
  final Widget child;

  const _SectionWithCurrent({
    required this.title,
    required this.trailingText,
    required this.onTrailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: onTrailing, child: Text(trailingText)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _PickerList<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(T) itemBuilder;

  const _PickerList({
    required this.title,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(title),
              subtitle: Text('เลือกจาก ${items.length} รายการ'),
            ),
            const Divider(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) => itemBuilder(items[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
