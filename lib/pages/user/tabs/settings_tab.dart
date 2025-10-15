// lib/pages/user/tabs/settings_tab.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../services/user_settings_service.dart';
import '../../../models/address_item.dart';
import '../../../models/payment_method_item.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

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
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
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
                    const ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('แก้ไขข้อมูลส่วนตัว'),
                      subtitle: Text('ชื่อ / นามสกุล / อีเมล / เบอร์โทรศัพท์'),
                    ),
                    TextFormField(
                      controller: firstCtrl,
                      decoration: const InputDecoration(labelText: 'ชื่อ'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกชื่อ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastCtrl,
                      decoration: const InputDecoration(
                          labelText: 'นามสกุล (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'อีเมล'),
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
                          labelText: 'เบอร์โทรศัพท์ (ไม่บังคับ)'),
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
                      child: ElevatedButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
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
                                          Text('อัปเดตข้อมูลส่วนตัวสำเร็จ'),
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
          );
        });
      },
    );
  }

  /* ------------------------ เปลี่ยนรหัสผ่าน ------------------------ */
  Future<void> _openChangePasswordSheet() async {
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

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
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
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
                    const ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('เปลี่ยนรหัสผ่าน'),
                      subtitle: Text('กรอกรหัสผ่านปัจจุบันเพื่อยืนยันตัวตน'),
                    ),
                    TextFormField(
                      controller: currentCtl,
                      obscureText: ob1,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่านปัจจุบัน',
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob1 ? Icons.visibility : Icons.visibility_off),
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
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob2 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setSt(() => ob2 = !ob2),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                        if (t.length < 6) return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                        if (t == currentCtl.text.trim()) {
                          return 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtl,
                      obscureText: ob3,
                      decoration: InputDecoration(
                        labelText: 'ยืนยันรหัสผ่านใหม่',
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob3 ? Icons.visibility : Icons.visibility_off),
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
                      child: ElevatedButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
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

                                  if (!mounted) return;
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
                                        content: Text(
                                            'ไม่สามารถเปลี่ยนรหัสผ่าน: $e')),
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
          );
        });
      },
    );
  }

  /* ------------------------ ที่อยู่จัดส่ง ------------------------ */
  Future<void> _openAddressSheet() async {
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
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
                              child: ListTile(
                                leading: Icon(a.isDefault
                                    ? Icons.star
                                    : Icons.location_on_outlined),
                                title: Text(a.fullName),
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
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

    final nameCtrl = TextEditingController(text: item?.fullName ?? displayName);
    final line1Ctrl = TextEditingController(text: item?.line1 ?? '');
    final line2Ctrl = TextEditingController(text: item?.line2 ?? '');
    final cityCtrl = TextEditingController(text: item?.city ?? '');
    final zipCtrl = TextEditingController(text: item?.zip ?? '');
    final formKey = GlobalKey<FormState>();
    bool isDefault = item?.isDefault ?? false;
    bool saving = false;

    // เก็บพิกัดล่าสุดจาก GPS (ถ้ากดปุ่ม)
    double? gpsLat, gpsLng;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          Future<void> _useGPS() async {
            try {
              // ขอสิทธิ์
              LocationPermission perm = await Geolocator.checkPermission();
              if (perm == LocationPermission.denied) {
                perm = await Geolocator.requestPermission();
              }
              if (perm == LocationPermission.deniedForever ||
                  perm == LocationPermission.denied) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('ไม่ได้รับอนุญาตตำแหน่ง')),
                );
                return;
              }

              final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.best,
              );
              gpsLat = pos.latitude;
              gpsLng = pos.longitude;

              // reverse geocode (Nominatim)
              final uri =
                  Uri.parse('https://nominatim.openstreetmap.org/reverse')
                      .replace(queryParameters: {
                'lat': pos.latitude.toString(),
                'lon': pos.longitude.toString(),
                'format': 'json',
                'zoom': '18',
                'addressdetails': '1',
              });

              final res = await http.get(uri, headers: {
                'User-Agent':
                    'flutter_application_2/1.0 (contact: you@example.com)',
              });
              if (res.statusCode != 200) {
                throw 'Reverse geocode error ${res.statusCode}';
              }

              final data = json.decode(res.body) as Map<String, dynamic>;
              final addr = (data['address'] ?? {}) as Map<String, dynamic>;

              final province =
                  (addr['state'] ?? addr['province'] ?? '') as String;
              final amphoe = (addr['county'] ??
                  addr['district'] ??
                  addr['city_district'] ??
                  '') as String;
              final tambon = (addr['suburb'] ??
                  addr['village'] ??
                  addr['town'] ??
                  addr['city'] ??
                  '') as String;
              final postcode = (addr['postcode'] ?? '') as String;

              final composed = [
                if (tambon.isNotEmpty) tambon,
                if (amphoe.isNotEmpty) amphoe,
                if (province.isNotEmpty) province,
              ].join(', ');

              setSt(() {
                if (line1Ctrl.text.trim().isEmpty) {
                  final dn = (data['display_name'] as String? ?? '')
                      .split(',')
                      .take(2)
                      .join(', ')
                      .trim();
                  if (dn.isNotEmpty) line1Ctrl.text = dn;
                }
                cityCtrl.text = composed;
                zipCtrl.text = postcode;
              });

              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                    content: Text('เติมที่อยู่จากตำแหน่งปัจจุบันแล้ว')),
              );
            } catch (e) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('ใช้ GPS ไม่สำเร็จ: $e')),
              );
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
                    const ListTile(
                      leading: Icon(Icons.edit_location_alt_outlined),
                      title: Text('เพิ่ม/แก้ไขที่อยู่'),
                      subtitle: Text('กรอกข้อมูลให้ครบถ้วน'),
                    ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'ชื่อผู้รับ'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกชื่อ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line1Ctrl,
                      decoration:
                          const InputDecoration(labelText: 'ที่อยู่บรรทัด 1'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกที่อยู่'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line2Ctrl,
                      decoration: const InputDecoration(
                          labelText: 'ที่อยู่บรรทัด 2 (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _useGPS,
                        icon: const Icon(Icons.my_location),
                        label: const Text('ใช้ตำแหน่งปัจจุบันเติมให้'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'เขต/อำเภอ/จังหวัด',
                      ),
                      readOnly: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: zipCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'รหัสไปรษณีย์'),
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
                      child: ElevatedButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
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

                                  // ถ้าอยากเก็บ lat/lng ของที่อยู่นี้ด้วย:
                                  // if (gpsLat != null && gpsLng != null) {
                                  //   await UserSettingsService.instance
                                  //     .updateAddressLocation(item?.id ?? newId, gpsLat!, gpsLng!);
                                  // }

                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(item == null
                                          ? 'เพิ่มที่อยู่สำเร็จ'
                                          : 'แก้ไขที่อยู่สำเร็จ'),
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
          );
        });
      },
    );
  }

  /* ------------------------ วิธีชำระเงิน ------------------------ */
  Future<void> _openPaymentSheet() async {
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('วิธีชำระเงิน'),
                    subtitle: const Text('เพิ่ม/แก้ไข/ตั้งค่า default'),
                    trailing: FilledButton.icon(
                      onPressed: () => _openEditPaymentForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มวิธีชำระ'),
                    ),
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: StreamBuilder<List<PaymentMethodItem>>(
                      stream: UserSettingsService.instance.paymentsStream(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return const Center(
                              child: Text('ยังไม่มีวิธีชำระเงิน'));
                        }
                        return ListView.builder(
                          controller: controller,
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            return Card(
                              child: ListTile(
                                leading: Icon(p.isDefault
                                    ? Icons.star
                                    : Icons.payment_outlined),
                                title: Text(p.label),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    try {
                                      if (v == 'edit') {
                                        _openEditPaymentForm(item: p, index: i);
                                      } else if (v == 'default') {
                                        await UserSettingsService.instance
                                            .setDefaultPayment(p.id);
                                      } else if (v == 'delete') {
                                        await UserSettingsService.instance
                                            .deletePayment(p.id);
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
                                            title: Text('แก้ไข'))),
                                    PopupMenuItem(
                                        value: 'default',
                                        child: ListTile(
                                            leading: Icon(Icons.star),
                                            title:
                                                Text('ตั้งเป็นค่าเริ่มต้น'))),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                            leading: Icon(Icons.delete_outline),
                                            title: Text('ลบ'))),
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

  Future<void> _openEditPaymentForm(
      {PaymentMethodItem? item, int? index}) async {
    if (!_isSignedIn) {
      _goLogin();
      return;
    }

    final labelCtrl = TextEditingController(text: item?.label ?? '');
    final formKey = GlobalKey<FormState>();
    bool isDefault = item?.isDefault ?? false;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
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
                    leading: Icon(Icons.account_balance_wallet_outlined),
                    title: Text('บันทึกวิธีชำระเงิน'),
                    subtitle:
                        Text('เช่น "บัตรเครดิต •••• 4242", "โอนธนาคารกสิกร"'),
                  ),
                  TextFormField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ชื่อ/คำอธิบายวิธีชำระ'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกข้อมูล'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isDefault,
                    onChanged: (val) => setSt(() => isDefault = val),
                    title: const Text('ตั้งเป็นวิธีชำระเริ่มต้น'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(saving ? 'กำลังบันทึก...' : 'บันทึกวิธีชำระ'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSt(() => saving = true);
                              try {
                                final newItem = PaymentMethodItem(
                                  id: item?.id ?? '',
                                  label: labelCtrl.text.trim(),
                                  isDefault: isDefault,
                                  updatedAt: DateTime.now(),
                                );
                                final newId = await UserSettingsService.instance
                                    .upsertPayment(newItem, id: item?.id);

                                if (isDefault) {
                                  await UserSettingsService.instance
                                      .setDefaultPayment(item?.id ?? newId);
                                }

                                if (!mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(item == null
                                        ? 'เพิ่มวิธีชำระเงินสำเร็จ'
                                        : 'แก้ไขวิธีชำระเงินสำเร็จ'),
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
          );
        });
      },
    );
  }

  /* ----------------------------- UI หลัก ----------------------------- */
  @override
  Widget build(BuildContext context) {
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
              ElevatedButton.icon(
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

    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(displayName),
          subtitle: Text(topSubtitle),
        ),
        const Divider(),
        const _SectionHeader('ข้อมูลบัญชี'),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('ชื่อผู้ใช้ / ผู้ติดต่อ'),
          subtitle: const Text('แก้ไขชื่อ–นามสกุล / อีเมล / เบอร์โทรศัพท์'),
          onTap: _openEditProfileSheet,
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email_outlined),
          title: const Text('อีเมล'),
          subtitle: Text(displayEmail),
          onTap: _openEditProfileSheet,
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('เปลี่ยนรหัสผ่าน'),
          onTap: _openChangePasswordSheet,
        ),
        const Divider(),
        const _SectionHeader('ที่อยู่จัดส่ง'),
        StreamBuilder<List<AddressItem>>(
          stream: UserSettingsService.instance.addressesStream(),
          builder: (context, snap) {
            final items = snap.data ?? const <AddressItem>[];
            final def = items.where((e) => e.isDefault).toList();
            final subtitle = def.isNotEmpty
                ? 'ค่าเริ่มต้น: ${def.first.fullName}'
                : 'ยังไม่ได้ตั้งค่าเริ่มต้น';
            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('ที่อยู่ทั้งหมด'),
              subtitle: Text(subtitle),
              onTap: _openAddressSheet,
            );
          },
        ),
        const Divider(),
        const _SectionHeader('การชำระเงิน'),
        StreamBuilder<List<PaymentMethodItem>>(
          stream: UserSettingsService.instance.paymentsStream(),
          builder: (context, snap) {
            final items = snap.data ?? const <PaymentMethodItem>[];
            final def = items.where((e) => e.isDefault).toList();
            final subtitle = def.isNotEmpty
                ? 'ค่าเริ่มต้น: ${def.first.label}'
                : 'ยังไม่ได้ตั้งค่าเริ่มต้น';
            return ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('วิธีชำระเงิน'),
              subtitle: Text(subtitle),
              onTap: _openPaymentSheet,
            );
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
                  '/login/user',
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

  void _goLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งานเมนูนี้')),
    );
    Navigator.pushNamed(context, '/login-user');
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
