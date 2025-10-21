// lib/pages/user/tabs/settings_tab.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../services/user_settings_service.dart';
import '../../../models/address_item.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late String displayName;
  late String displayEmail;
  String displayPhone = '';

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  StreamSubscription<Map<String, dynamic>?>? _profileSub;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    displayName =
        u?.displayName ?? (AuthService.instance.currentUser?.name ?? 'ผู้ใช้');
    displayEmail = u?.email ?? (AuthService.instance.currentUser?.email ?? '');
    displayPhone = AuthService.instance.currentUser?.phone ?? '';

    if (_isSignedIn) {
      _profileSub =
          UserSettingsService.instance.profileStream().listen((profile) {
        if (!mounted || profile == null) return;
        setState(() {
          displayName = profile['name'] ?? displayName;
          displayEmail = profile['email'] ?? displayEmail;
          displayPhone = profile['phone'] ?? displayPhone;
        });
      });
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  /* ------------------------ โปรไฟล์ ------------------------ */
  Future<void> _openEditProfileSheet() async {
    if (!_isSignedIn) return _goLogin();

    String first = displayName.trim();
    String last = '';
    if (displayName.contains(' ')) {
      final parts = displayName.split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.sublist(1).join(' ');
    }

    final firstCtrl = TextEditingController(text: first);
    final lastCtrl = TextEditingController(text: last);
    final emailCtrl = TextEditingController(text: displayEmail);
    final phoneCtrl = TextEditingController(text: displayPhone);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SectionHeader(
                      icon: Icons.person_outline, text: 'แก้ไขข้อมูลส่วนตัว'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: firstCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ชื่อ', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อ'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(
                        labelText: 'นามสกุล (ไม่บังคับ)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'อีเมล', border: OutlineInputBorder()),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      final r = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (text.isEmpty) return 'กรุณากรอกอีเมล';
                      if (!r.hasMatch(text)) return 'อีเมลไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'เบอร์โทรศัพท์ (ไม่บังคับ)',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final r = RegExp(r'^[0-9+\-\s]{6,}$');
                      if (!r.hasMatch(t)) return 'รูปแบบเบอร์โทรไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSt(() => saving = true);
                              try {
                                final fullName = [
                                  firstCtrl.text.trim(),
                                  if (lastCtrl.text.trim().isNotEmpty)
                                    lastCtrl.text.trim(),
                                ].join(' ');

                                await UserSettingsService.instance
                                    .updateProfile(
                                  name: fullName,
                                  email: emailCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );

                                await AuthService.instance.updateProfile(
                                  name: fullName,
                                  email: emailCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );

                                if (!mounted) return;
                                setState(() {
                                  displayName = fullName;
                                  displayEmail = emailCtrl.text.trim();
                                  displayPhone = phoneCtrl.text.trim();
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('อัปเดตข้อมูลส่วนตัวสำเร็จ')),
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
      ),
    );
  }

  /* ------------------------ เปลี่ยนรหัสผ่าน ------------------------ */
  Future<void> _openChangePasswordSheet() async {
    if (!_isSignedIn) return _goLogin();
    if (displayEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('บัญชีนี้ไม่มีอีเมล จึงไม่สามารถเปลี่ยนรหัสผ่านได้')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final currentCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    bool saving = false;
    bool ob1 = true, ob2 = true, ob3 = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SectionHeader(
                      icon: Icons.lock_outline, text: 'เปลี่ยนรหัสผ่าน'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: currentCtl,
                    obscureText: ob1,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่านปัจจุบัน',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon:
                            Icon(ob1 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setSt(() => ob1 = !ob1),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกรหัสผ่านปัจจุบัน'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtl,
                    obscureText: ob2,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon:
                            Icon(ob2 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setSt(() => ob2 = !ob2),
                      ),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                      if (t.length < 6) return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                      if (t == currentCtl.text.trim())
                        return 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtl,
                    obscureText: ob3,
                    decoration: InputDecoration(
                      labelText: 'ยืนยันรหัสผ่านใหม่',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon:
                            Icon(ob3 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setSt(() => ob3 = !ob3),
                      ),
                    ),
                    validator: (v) => (v?.trim() != newCtl.text.trim())
                        ? 'รหัสผ่านยืนยันไม่ตรงกัน'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(
                          saving ? 'กำลังบันทึก...' : 'ยืนยันการเปลี่ยนรหัส'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSt(() => saving = true);
                              try {
                                await AuthService.instance.changePassword(
                                  oldPassword: currentCtl.text.trim(),
                                  newPassword: newCtl.text.trim(),
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('เปลี่ยนรหัสผ่านเรียบร้อย')),
                                );
                              } catch (e) {
                                setSt(() => saving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('ไม่สามารถเปลี่ยนรหัสผ่าน: $e')),
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
      ),
    );
  }

  /* ------------------------ ที่อยู่จัดส่ง ------------------------ */
  Future<void> _openAddressSheet() async {
    if (!_isSignedIn) return _goLogin();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            final theme = Theme.of(ctx);
            final primary = theme.colorScheme.primary;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on_outlined),
                    ),
                    title: const Text('ที่อยู่ทั้งหมด'),
                    subtitle: const Text('เพิ่ม/แก้ไข/ตั้งค่า default'),
                    trailing: FilledButton.icon(
                      onPressed: () => _openEditAddressForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มที่อยู่'),
                    ),
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: StreamBuilder<List<AddressItem>>(
                      stream: UserSettingsService.instance.addressesStream(),
                      initialData: const [],
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text('❌ เกิดข้อผิดพลาด: ${snap.error}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return const Center(child: Text('ยังไม่มีที่อยู่'));
                        }
                        return ListView.builder(
                          controller: controller,
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final a = items[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: Icon(a.isDefault
                                    ? Icons.star
                                    : Icons.location_on_outlined),
                                title: Text(a.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${a.line1}${a.line2.isNotEmpty ? '\n${a.line2}' : ''}\n${a.city} ${a.zip}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    try {
                                      if (v == 'edit') {
                                        _openEditAddressForm(item: a, index: i);
                                      } else if (v == 'default') {
                                        await UserSettingsService.instance
                                            .setDefaultAddress(a.id);
                                      } else if (v == 'delete') {
                                        await UserSettingsService.instance
                                            .deleteAddress(a.id);
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('แก้ไข'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'default',
                                      child: ListTile(
                                        leading: Icon(Icons.star),
                                        title: Text('ตั้งเป็นค่าเริ่มต้น'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline),
                                        title: Text('ลบ'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditAddressForm({AddressItem? item, int? index}) async {
    if (!_isSignedIn) return _goLogin();

    final nameCtrl = TextEditingController(text: item?.fullName ?? displayName);
    final line1Ctrl = TextEditingController(text: item?.line1 ?? '');
    final line2Ctrl = TextEditingController(text: item?.line2 ?? '');
    final cityCtrl = TextEditingController(text: item?.city ?? '');
    final zipCtrl = TextEditingController(text: item?.zip ?? '');
    final formKey = GlobalKey<FormState>();
    bool isDefault = item?.isDefault ?? false;
    bool saving = false;

    // GPS
    double? gpsLat, gpsLng;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool gpsLoading = false;

          Future<void> useGPS() async {
            try {
              setSt(() => gpsLoading = true);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('กำลังอ่านตำแหน่ง...')),
              );

              // 1) Service (เฉพาะ non-web)
              if (!kIsWeb) {
                final serviceOn = await Geolocator.isLocationServiceEnabled();
                if (!serviceOn) {
                  setSt(() => gpsLoading = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('กรุณาเปิดบริการตำแหน่ง (Location)')),
                  );
                  await Geolocator.openLocationSettings();
                  return;
                }
              }

              // 2) Permission
              LocationPermission perm = await Geolocator.checkPermission();
              if (perm == LocationPermission.denied) {
                perm = await Geolocator.requestPermission();
              }
              if (perm == LocationPermission.deniedForever ||
                  perm == LocationPermission.denied) {
                setSt(() => gpsLoading = false);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง')),
                );
                return;
              }

              // 3) Last known (non-web)
              if (!kIsWeb) {
                try {
                  final last = await Geolocator.getLastKnownPosition();
                  if (last != null) {
                    gpsLat = last.latitude;
                    gpsLng = last.longitude;
                  }
                } catch (_) {}
              }

              // 4) Get current (web: ลองหลายครั้งแล้วเลือกดีที่สุด)
              Position pos;
              if (kIsWeb) {
                Position? best;
                for (var i = 0; i < 3; i++) {
                  try {
                    final p = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.bestForNavigation,
                    ).timeout(const Duration(seconds: 6));
                    if (best == null || p.accuracy < best.accuracy) best = p;
                  } catch (_) {}
                  await Future.delayed(const Duration(milliseconds: 500));
                }
                best ??= await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.bestForNavigation,
                ).timeout(const Duration(seconds: 12));
                pos = best!;
              } else {
                pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.bestForNavigation,
                ).timeout(const Duration(seconds: 12));
              }

              gpsLat = pos.latitude;
              gpsLng = pos.longitude;

              // เติมค่าเบื้องต้นเผื่อ reverse พัง
              setSt(() {
                if (line1Ctrl.text.trim().isEmpty) {
                  line1Ctrl.text =
                      'Lat ${gpsLat!.toStringAsFixed(6)}, Lng ${gpsLng!.toStringAsFixed(6)}';
                }
              });

              // 5) Reverse geocode (web: ห้ามส่ง User-Agent เพื่อเลี่ยง CORS)
              try {
                final uri =
                    Uri.parse('https://nominatim.openstreetmap.org/reverse')
                        .replace(
                  queryParameters: {
                    'lat': gpsLat!.toString(),
                    'lon': gpsLng!.toString(),
                    'format': 'json',
                    'zoom': '18',
                    'addressdetails': '1',
                    'accept-language': 'th', // ขอข้อมูลเป็นภาษาไทย
                  },
                );

                final headers = <String, String>{};
                if (!kIsWeb) {
                  headers['User-Agent'] =
                      'flutter_application_2/1.0 (contact: you@example.com)';
                }

                final res = await http.get(uri, headers: headers);

                if (res.statusCode == 200) {
                  final data = json.decode(res.body) as Map<String, dynamic>;
                  final addr = (data['address'] ?? {}) as Map<String, dynamic>;

                  String _clean(String s) =>
                      s.trim().replaceAll(RegExp(r'\s+'), ' ');
                  String _stripPrefix(String s) => s.replaceAll(
                      RegExp(r'^(Chang Wat|Amphoe|Khet)\s+',
                          caseSensitive: false),
                      '');

                  final provinceRaw = (addr['state'] ?? addr['province'] ?? '')
                      as String; // จังหวัด
                  final amphoeRaw = (addr['county'] ??
                      addr['district'] ??
                      addr['city_district'] ??
                      '') as String; // อำเภอ/เขต
                  final postcode = (addr['postcode'] ?? '') as String;

                  final province = _clean(_stripPrefix(provinceRaw));
                  final amphoe = _clean(_stripPrefix(amphoeRaw));
                  final isBKK =
                      province == 'Bangkok' || province == 'กรุงเทพมหานคร';

                  final cityText = isBKK
                      ? (amphoe.isNotEmpty
                          ? 'เขต $amphoe, กรุงเทพมหานคร'
                          : 'กรุงเทพมหานคร')
                      : [
                          if (amphoe.isNotEmpty) 'อำเภอ $amphoe',
                          if (province.isNotEmpty) 'จังหวัด $province',
                        ].join(', ');

                  setSt(() {
                    if ((line1Ctrl.text.trim().isEmpty) &&
                        (data['display_name'] is String)) {
                      final dn = (data['display_name'] as String)
                          .split(',')
                          .take(2)
                          .join(', ')
                          .trim();
                      if (dn.isNotEmpty) line1Ctrl.text = dn;
                    }
                    cityCtrl.text = cityText;
                    if (postcode.isNotEmpty) zipCtrl.text = postcode;
                  });

                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('เติมที่อยู่แล้ว')),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(
                            'แปลงที่อยู่ไม่สำเร็จ (HTTP ${res.statusCode})')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('แปลงที่อยู่ไม่สำเร็จ: $e')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('ใช้ GPS ไม่สำเร็จ: $e')),
              );
            } finally {
              setSt(() => gpsLoading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SectionHeader(
                        icon: Icons.edit_location_alt_outlined,
                        text: 'เพิ่ม/แก้ไขที่อยู่'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: gpsLoading ? null : useGPS,
                        icon: gpsLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: Text(gpsLoading
                            ? 'กำลังอ่านตำแหน่ง...'
                            : 'ใช้ตำแหน่งปัจจุบันเติมให้'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'ชื่อผู้รับ',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกชื่อ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line1Ctrl,
                      decoration: const InputDecoration(
                          labelText: 'ที่อยู่บรรทัด 1',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกที่อยู่'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line2Ctrl,
                      decoration: const InputDecoration(
                          labelText: 'ที่อยู่บรรทัด 2 (ไม่บังคับ)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                          labelText: 'เขต/อำเภอ/จังหวัด',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: zipCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'รหัสไปรษณีย์',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'รหัสไปรษณีย์ไม่ถูกต้อง'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isDefault,
                      onChanged: (val) => setSt(() => isDefault = val),
                      title: const Text('ตั้งเป็นที่อยู่เริ่มต้น'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label:
                            Text(saving ? 'กำลังบันทึก...' : 'บันทึกที่อยู่'),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSt(() => saving = true);
                                try {
                                  final newItem = AddressItem(
                                    id: item?.id ?? '',
                                    fullName: nameCtrl.text.trim(),
                                    line1: line1Ctrl.text.trim(),
                                    line2: line2Ctrl.text.trim(),
                                    city: cityCtrl.text.trim(),
                                    zip: zipCtrl.text.trim(),
                                    isDefault: isDefault,
                                    updatedAt: DateTime.now(),
                                  );

                                  final newId = await UserSettingsService
                                      .instance
                                      .upsertAddress(newItem, id: item?.id);

                                  if (isDefault) {
                                    await UserSettingsService.instance
                                        .setDefaultAddress(item?.id ?? newId);
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(item == null
                                            ? 'เพิ่มที่อยู่สำเร็จ'
                                            : 'แก้ไขที่อยู่สำเร็จ')),
                                  );
                                } catch (e) {
                                  setSt(() => saving = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.toString())));
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /* ----------------------------- UI หลัก ----------------------------- */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (!_isSignedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 12),
              const Text('กรุณาเข้าสู่ระบบเพื่อจัดการข้อมูลบัญชี'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _goLogin,
                icon: const Icon(Icons.login),
                label: const Text('ไปหน้าเข้าสู่ระบบ'),
              ),
            ],
          ),
        ),
      );
    }

    final topSubtitle = [
      if (displayEmail.isNotEmpty) displayEmail,
      if (displayPhone.isNotEmpty) 'โทร: $displayPhone',
    ].join('\n');

    // Header
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.settings,
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.7)),
          const SizedBox(width: 8),
          Text('ตั้งค่าบัญชี',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    // Profile Card (Material e1, โค้ง 10px)
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person, size: 28),
          ),
          title: Text(displayName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              if (displayEmail.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    displayEmail,
                    style: TextStyle(
                      color: primary.withOpacity(.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (displayPhone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('โทร: $displayPhone',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );

    // Group: Account
    final accountGroup = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.person_pin_circle_outlined, text: 'ข้อมูลบัญชี'),
          const SizedBox(height: 6),
          Material(
            elevation: 1,
            shadowColor: Colors.black12,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('ชื่อผู้ใช้ / ผู้ติดต่อ'),
                  subtitle:
                      const Text('แก้ไขชื่อ–นามสกุล / อีเมล / เบอร์โทรศัพท์'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openEditProfileSheet,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.alternate_email_outlined),
                  title: const Text('อีเมล'),
                  subtitle: Text(displayEmail.isEmpty ? '-' : displayEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openEditProfileSheet,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('เปลี่ยนรหัสผ่าน'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openChangePasswordSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Group: Address
    final addressGroup = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.home_outlined, text: 'ที่อยู่จัดส่ง'),
          const SizedBox(height: 6),
          Material(
            elevation: 1,
            shadowColor: Colors.black12,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            child: StreamBuilder<List<AddressItem>>(
              stream: UserSettingsService.instance.addressesStream(),
              builder: (context, snap) {
                final items = snap.data ?? const <AddressItem>[];
                final def = items.where((e) => e.isDefault).toList();
                final subtitle = def.isNotEmpty
                    ? 'ค่าเริ่มต้น: ${def.first.fullName}'
                    : 'ยังไม่ได้ตั้งค่าเริ่มต้น';
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('ที่อยู่ทั้งหมด'),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openAddressSheet,
                );
              },
            ),
          ),
        ],
      ),
    );

    // Logout button: Outlined
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
                context, '/login/user', (_) => false);
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
        addressGroup,
        logoutBtn,
      ],
    );
  }

  void _goLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งานเมนูนี้')),
    );
    Navigator.pushNamed(context, '/login-user');
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
