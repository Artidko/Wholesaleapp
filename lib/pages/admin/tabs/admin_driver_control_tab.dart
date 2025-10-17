import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/driver_location_service.dart';
// ถ้ามี util ขอสิทธิ์ ให้ import ด้วย
// import '../../../utils/location_permission.dart';

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
    if (uid == null) return;

    // ✅ ให้ชื่อฟิลด์ตรงกับ rules ของคุณ (เลือก driverUid หรือ driverId แล้วใช้ทั้งโปรเจกต์)
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'driverUid': uid, // ถ้าใช้ driverId ให้เปลี่ยนตรงนี้ + rules ให้ตรงกัน
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _start() async {
    final id = _selectedOrderId;
    if (id == null) return;

    // ถ้ามีฟังก์ชันขอสิทธิ์ให้เรียกก่อน
    // if (!await ensureLocationPermission()) return;

    await _assignMeAsDriver(id);
    await DriverLocationService.instance.startTrackingOrder(
      id,
      alsoAppendHistory: true,
    );
    setState(() {}); // รีเฟรชปุ่มตาม isRunning
  }

  void _stop() async {
    await DriverLocationService.instance.stop();
    setState(() {});
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
                      final docs = snap.data?.docs ?? [];
                      return DropdownButtonFormField<String>(
                        value: _selectedOrderId,
                        hint: const Text('เลือกออเดอร์ที่กำลังจัดส่ง'),
                        items: docs.map((d) {
                          final id = d.id;
                          final dest = d.data()['dest'];
                          final desc = dest != null
                              ? '(${(dest['lat'] as num).toStringAsFixed(4)}, ${(dest['lng'] as num).toStringAsFixed(4)})'
                              : '';
                          return DropdownMenuItem(
                            value: id,
                            child: Text('#$id $desc',
                                overflow: TextOverflow.ellipsis),
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
              'หมายเหตุ: เมื่อกด "เริ่มแชร์ตำแหน่ง" ระบบจะตั้ง driverUid ให้เป็นบัญชีแอดมินของอุปกรณ์นี้ และส่งพิกัดแบบเรียลไทม์ไปยังออเดอร์ที่เลือก',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
