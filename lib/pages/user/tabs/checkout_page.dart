// lib/pages/user/tabs/checkout_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 3rd-party
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Project
import '../../../services/user_settings_service.dart';
import '../../../models/address_item.dart';
import '../../../models/payment_method_item.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/order_service.dart';
import '../../widgets/order_view_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  AddressItem? _selectedAddress;
  PaymentMethodItem? _selectedPayment;

  // เก็บสลิปไว้ก่อน (จะอัปโหลดหลังสร้างออเดอร์)
  Uint8List? _pendingSlipBytes;
  String? _pendingSlipName;

  bool _submitting = false;
  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  // รูป QR พร้อมเพย์ (วางไฟล์ไว้ตาม path นี้ และประกาศใน pubspec แล้ว)
  static const String _qrAssetPath = 'assets/qr/qr_promptpay_kplus.jpg';

  @override
  void initState() {
    super.initState();
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

    final canSubmit =
        _selectedAddress != null && _selectedPayment != null && !_submitting;

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
            onPickSlip: _pickSlip,
            qrAssetPath: _qrAssetPath,
            hasPendingSlip: _pendingSlipBytes != null,
          ),
          if (_pendingSlipBytes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'แนบสลิปรออัปโหลดหลังสร้างออเดอร์'
                    '${_pendingSlipName != null ? ' (${_pendingSlipName})' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() =>
                      {_pendingSlipBytes = null, _pendingSlipName = null}),
                  child: const Text('เอาออก'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle),
            label: Text(_submitting
                ? 'กำลังสร้างออเดอร์...'
                : 'ยืนยันชำระเงินและสร้างออเดอร์'),
          ),
          const SizedBox(height: 12),
          if (_selectedAddress == null || _selectedPayment == null)
            const Text('กรุณาเลือกที่อยู่จัดส่งและวิธีชำระเงิน',
                textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _pickSlip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    if (f.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถอ่านไฟล์สลิปได้')),
      );
      return;
    }
    setState(() {
      _pendingSlipBytes = f.bytes!;
      _pendingSlipName = f.name;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('เลือกสลิปแล้ว – จะอัปโหลดหลังสร้างออเดอร์')),
    );
  }

  Future<void> _submit() async {
    if (_selectedAddress == null || _selectedPayment == null) return;

    final cart = context.read<CartProvider>();
    if (cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ตะกร้าว่าง ไม่สามารถสร้างออเดอร์ได้')),
      );
      return;
    }

    setState(() => _submitting = true);

    String? orderId;

    // ---------------------- เฟสที่ 1: "สร้างออเดอร์" ----------------------
    try {
      final a = _selectedAddress!;
      final addressText = '${a.fullName}\n'
          '${a.line1}${a.line2.isNotEmpty ? '\n${a.line2}' : ''}\n'
          '${a.city} ${a.zip}';

      final p = _selectedPayment!;
      final paymentDetail = switch (p.type) {
        PaymentType.cod => 'ชำระปลายทาง',
        PaymentType.promptpay => 'พร้อมเพย์: ${p.promptPayId ?? '-'}',
        _ => '',
      };
      final paymentText =
          '${p.label}${paymentDetail.isNotEmpty ? ' • $paymentDetail' : ''}';

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final dest =
          (userDoc.data()?['defaultLocation'] as Map<String, dynamic>?);
      if (dest == null || dest['lat'] == null || dest['lng'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ยังไม่ได้ตั้ง “พิกัดเริ่มต้น” ในโปรไฟล์ผู้ใช้')),
        );
        setState(() => _submitting = false);
        return;
      }

      final destLat = (dest['lat'] as num).toDouble();
      final destLng = (dest['lng'] as num).toDouble();
      final markPaidNow = p.type == PaymentType.cod;

      orderId = await OrderService.instance
          .createOrderFromCart(
            cart: cart,
            addressText: addressText,
            paymentText: paymentText,
            destLat: destLat,
            destLng: destLng,
            shippingFee: 0,
            markPaid: markPaidNow,
          )
          .timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('สร้างออเดอร์ล้มเหลว (${e.code}): ${e.message}')),
      );
      setState(() => _submitting = false);
      return; // ❌ จบที่นี่เพราะสร้างออเดอร์ไม่สำเร็จ
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('เครือข่ายช้า: สร้างออเดอร์เกินเวลา กรุณาลองใหม่')),
      );
      setState(() => _submitting = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้างออเดอร์ไม่สำเร็จ: $e')),
      );
      setState(() => _submitting = false);
      return;
    }

    // ---------------------- เฟสที่ 2: "อัปโหลดสลิป" (ไม่บล็อกออเดอร์) ----------------------
    try {
      final p = _selectedPayment!;
      if (p.type == PaymentType.promptpay && _pendingSlipBytes != null) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await _uploadSlipToSupabase(orderId!, uid, _pendingSlipBytes!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('แนบสลิปเรียบร้อย รอแอดมินตรวจสอบ')),
          );
        }
      }
    } catch (e) {
      // ไม่ถือว่า fail ของออเดอร์—แค่แจ้งเตือนว่าแนบสลิปไม่สำเร็จ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ออเดอร์ถูกสร้างแล้ว แต่แนบสลิปไม่สำเร็จ: $e'),
          ),
        );
      }
    }

    // ---------------------- ไปหน้ารายละเอียดออเดอร์ ----------------------
    if (!mounted) return;
    setState(() => _submitting = false);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderViewPage(orderId: orderId!)),
    );
  }

  /// อัปโหลดสลิปขึ้น Supabase + อัปเดตฟิลด์ payment ใน Firestore
  Future<void> _uploadSlipToSupabase(
    String orderId,
    String uid,
    Uint8List bytes,
  ) async {
    final supabase = Supabase.instance.client;
    const bucket = 'slips';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'orders/$orderId/slips/${uid}_$ts.jpg';

    // อัปโหลดไป Supabase (บัคเก็ตต้อง Public หรือมีนโยบายอ่านได้)
    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final slipUrl = supabase.storage.from(bucket).getPublicUrl(path);

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'payment': {
        'method': 'promptpay',
        'slipUrl': slipUrl,
        'submittedBy': uid,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewStatus': 'pending', // pending | approved | rejected
        'storage': 'supabase',
        'bucket': bucket,
        'path': path,
      },
      'statusClientNote': 'ส่งสลิปแล้ว รอแอดมินตรวจสอบ',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/* ====================== Address Section ====================== */

class _AddressSection extends StatelessWidget {
  final AddressItem? initial;
  final ValueChanged<AddressItem> onPick;
  const _AddressSection({required this.onPick, this.initial});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<List<AddressItem>>(
        stream: UserSettingsService.instance.addressesStream(),
        initialData: const [],
        builder: (context, snap) {
          if (snap.hasError)
            return _SectionError('ที่อยู่จัดส่ง', snap.error.toString());
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
            leading:
                Icon(a.isDefault ? Icons.star : Icons.location_on_outlined),
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

/* ====================== Payment Section ====================== */

class _PaymentSection extends StatelessWidget {
  final PaymentMethodItem? initial;
  final ValueChanged<PaymentMethodItem> onPick;

  final VoidCallback onPickSlip;
  final String qrAssetPath;
  final bool hasPendingSlip;

  const _PaymentSection({
    required this.onPick,
    this.initial,
    required this.onPickSlip,
    required this.qrAssetPath,
    required this.hasPendingSlip,
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
          if (initial == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onPick(selected));
          }

          return _SectionWithCurrent(
            title: 'เลือกวิธีการชำระเงิน',
            trailingText: 'เปลี่ยน',
            onTrailing: () => _openPicker(context, items),
            child: _PaymentSummary(
              selected: selected,
              onShowQr: () => _showPromptPayQR(context, selected),
              hasPendingSlip: hasPendingSlip,
              onPickSlip: onPickSlip,
              qrAssetPath: qrAssetPath,
            ),
          );
        },
      ),
    );
  }

  PaymentMethodItem _pickInitialPayment(
      List<PaymentMethodItem> items, PaymentMethodItem? init) {
    if (init != null) {
      final match = items.where((e) => e.id == init.id);
      return match.isNotEmpty ? match.first : init;
    }
    final def = items.where((e) => e.isDefault).toList();
    if (def.isNotEmpty) return def.first;
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

  void _showPromptPayQR(BuildContext context, PaymentMethodItem p) {
    if (p.type != PaymentType.promptpay) return;

    final id = p.promptPayId ?? '';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxImgHeight = mq.size.height * 0.55;

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('QR พร้อมเพย์'),
                    subtitle: Text('ปลายทาง: $id'),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: maxImgHeight,
                      maxWidth: mq.size.width,
                    ),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(qrAssetPath, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('หลังสแกน กรุณาแนบสลิปเพื่อให้แอดมินตรวจสอบ',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickSlip,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('เลือกสลิปโอนเงิน'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (hasPendingSlip)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 6),
                        Text('เลือกสลิปแล้ว (จะอัปโหลดหลังสร้างออเดอร์)'),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  final PaymentMethodItem selected;
  final VoidCallback onShowQr;
  final VoidCallback onPickSlip;
  final bool hasPendingSlip;
  final String qrAssetPath;

  const _PaymentSummary({
    required this.selected,
    required this.onShowQr,
    required this.onPickSlip,
    required this.hasPendingSlip,
    required this.qrAssetPath,
  });

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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2),
                label: const Text('ดู QR พร้อมเพย์'),
                onPressed: onShowQr,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label:
                    Text(hasPendingSlip ? 'เลือกสลิปแล้ว' : 'เลือกสลิปไว้ก่อน'),
                onPressed: onPickSlip,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasPendingSlip)
            const Text('หมายเหตุ: จะอัปโหลดอัตโนมัติหลังสร้างออเดอร์',
                style: TextStyle(fontSize: 12)),
        ],
      ],
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
      subtitle: Text(message, style: const TextStyle(color: Colors.red)),
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
