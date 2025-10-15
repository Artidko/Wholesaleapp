import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/driver_location_service.dart';

class AdminRiderControlTab extends StatefulWidget {
  const AdminRiderControlTab({super.key});

  @override
  State<AdminRiderControlTab> createState() => _AdminRiderControlTabState();
}

class _AdminRiderControlTabState extends State<AdminRiderControlTab> {
  String? _selectedOrderId;
  bool _tracking = false;

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
    // ให้แอดมินเป็น driver ของออเดอร์นี้ (อุปกรณ์นี้จะเป็นเครื่องที่แชร์พิกัด)
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'driverId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _start() async {
    final id = _selectedOrderId;
    if (id == null) return;
    await _assignMeAsDriver(id); // กันพลาด: ตั้ง driverId = admin คนนี้
    await DriverLocationService.instance.startTrackingOrder(id);
    setState(() => _tracking = true);
  }

  void _stop() {
    DriverLocationService.instance.stop();
    setState(() => _tracking = false);
  }

  @override
  void dispose() {
    DriverLocationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โหมดไรเดอร์ (ฝั่งแอดมิน)')),
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
                    onPressed: (!_tracking && _selectedOrderId != null)
                        ? _start
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('เริ่มแชร์ตำแหน่ง'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _tracking ? _stop : null,
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
              'หมายเหตุ: เมื่อกด "เริ่มแชร์ตำแหน่ง" ระบบจะตั้ง driverId ให้เป็นบัญชีแอดมินที่ใช้อุปกรณ์นี้ แล้วส่งพิกัดแบบเรียลไทม์ไปยังออเดอร์นั้น',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
