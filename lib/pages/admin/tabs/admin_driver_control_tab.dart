// lib/pages/admin/tabs/admin_driver_control_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../services/driver_location_service.dart';

class AdminDriverControlTab extends StatefulWidget {
  const AdminDriverControlTab({super.key});

  @override
  State<AdminDriverControlTab> createState() => _AdminDriverControlTabState();
}

class _AdminDriverControlTabState extends State<AdminDriverControlTab> {
  String? _selectedOrderId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _deliveringOrders() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivering')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _assignMeAsDriver(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw 'ยังไม่ได้เข้าสู่ระบบ';
    // ใช้ชื่อฟิลด์เดียวกันทั้งโปรเจ็กต์ (driverUid)
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'driverUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _start() async {
    final id = _selectedOrderId;
    if (id == null) return;

    try {
      await _assignMeAsDriver(id);

      // session ใหม่ทุกครั้งที่เริ่มแชร์
      final sessionId = const Uuid().v4();

      // เปิดแฟลก + เขียน session ที่ฝั่ง user ใช้รีเซ็ตเส้นทาง
      await FirebaseFirestore.instance.collection('orders').doc(id).set({
        'trackingActive': true,
        'current': {'sessionId': sessionId},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // เริ่มสตรีมพิกัด (service ของคุณต้องรองรับ sessionId)
      await DriverLocationService.instance.startTrackingOrder(
        id,
        alsoAppendHistory: true,
        sessionId: sessionId,
      );

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เริ่มแชร์ตำแหน่งแล้ว')),
        );
      }
    } catch (e) {
      // ปิดแฟลกถ้าเริ่มไม่สำเร็จ
      await FirebaseFirestore.instance.collection('orders').doc(id).set({
        'trackingActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เริ่มแชร์ไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _stop() async {
    final id = _selectedOrderId;
    try {
      await DriverLocationService.instance.stop();
    } finally {
      if (id != null) {
        await FirebaseFirestore.instance.collection('orders').doc(id).set({
          'trackingActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('หยุดแชร์ตำแหน่งแล้ว')),
      );
    }
  }

  @override
  void dispose() {
    DriverLocationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = DriverLocationService.instance.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('โหมด Driver (ฝั่งแอดมิน)')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _deliveringOrders(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      return DropdownButtonFormField<String>(
                        value: _selectedOrderId,
                        hint: const Text('เลือกออเดอร์ที่กำลังจัดส่ง'),
                        items: docs.map((d) {
                          final id = d.id;
                          final dest = d.data()['dest'];
                          String desc = '';
                          if (dest is Map) {
                            final lat = (dest['lat'] as num?)?.toDouble();
                            final lng = (dest['lng'] as num?)?.toDouble();
                            if (lat != null && lng != null) {
                              desc =
                                  '(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
                            }
                          }
                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              '#$id $desc',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedOrderId = v),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'รีเฟรช',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        (!running && _selectedOrderId != null) ? _start : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('เริ่มแชร์ตำแหน่ง'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: running ? _stop : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('หยุดแชร์ตำแหน่ง'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'หมายเหตุ: เมื่อกด "เริ่มแชร์ตำแหน่ง" ระบบจะตั้ง driverUid เป็นบัญชีปัจจุบัน เปิด trackingActive และส่งพิกัดเรียลไทม์ให้เอกสารออเดอร์',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
