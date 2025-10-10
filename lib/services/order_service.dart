// lib/services/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../providers/cart_provider.dart';

class OrderService {
  OrderService._();
  static final instance = OrderService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  /// ---------- Helpers ----------
  OrderStatus _fromStr(String s) {
    try {
      return OrderStatus.values.byName(s);
    } catch (_) {
      return OrderStatus.pending;
    }
  }

  bool _isValidTransition(OrderStatus from, OrderStatus to) {
    // Flow: pending -> paid -> preparing -> delivering -> completed (+ cancelled branch)
    return switch ((from, to)) {
      (OrderStatus.pending, OrderStatus.paid) ||
      (OrderStatus.pending, OrderStatus.cancelled) ||
      (OrderStatus.paid, OrderStatus.preparing) ||
      (OrderStatus.paid, OrderStatus.cancelled) ||
      (OrderStatus.preparing, OrderStatus.delivering) ||
      (OrderStatus.preparing, OrderStatus.cancelled) ||
      (OrderStatus.delivering, OrderStatus.completed) =>
        true,
      _ => false,
    };
  }

  /// ---------- Create ----------
  /// สร้างออเดอร์ใหม่จากตะกร้า แล้วคืนค่า orderId
  Future<String> createOrderFromCart({
    required CartProvider cart,
    required String addressText,
    required String paymentText,
    num shippingFee = 0,
    bool markPaid = true, // ถ้าจ่ายสำเร็จแล้ว
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ต้องล็อกอินก่อนทำรายการสั่งซื้อ');
    if (cart.isEmpty) throw Exception('ตะกร้าว่าง ไม่สามารถสร้างออเดอร์ได้');

    // map cart -> order lines
    final lines = cart.lines.map((l) {
      final p = l.product;
      return OrderLine(
        productId: p.id,
        name: p.name,
        imageUrl: p.imageUrl,
        qty: l.qty,
        price: p.price,
      );
    }).toList();

    final subTotal = cart.totalPrice;
    final grandTotal = subTotal + shippingFee;
    final initialStatus = markPaid ? OrderStatus.paid : OrderStatus.pending;

    // ใช้ serverTimestamp เฉพาะฟิลด์บนสุด; ภายใน array ใช้ Timestamp.now()
    final payload = {
      'userId': user.uid,
      'lines': lines.map((e) => e.toMap()).toList(),
      'subTotal': subTotal,
      'shippingFee': shippingFee,
      'grandTotal': grandTotal,
      'addressText': addressText,
      'paymentText': paymentText,
      'status': initialStatus.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'timeline': [
        {'status': initialStatus.name, 'at': Timestamp.now()}
      ],
    };

    // สร้างเอกสาร
    final ref = await _orders.add(payload);

    // (ออปชัน) เขียน id ซ้ำเข้าไปที่เอกสารด้วย เผื่ออยาก query/แสดงง่าย
    await ref.update({'id': ref.id});

    // เคลียร์ตะกร้าหลังสั่งสำเร็จ
    cart.clear();
    return ref.id;
  }

  /// ---------- Read ----------
  Future<OrderModel> getOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    if (!doc.exists) throw Exception('ไม่พบคำสั่งซื้อ');
    return OrderModel.fromDoc(doc);
  }

  /// ออเดอร์ของผู้ใช้แบบเรียลไทม์ (ใหม่สุดก่อน)
  /// *ต้องสร้าง Composite Index: where(userId) + orderBy(createdAt)
  Stream<List<OrderModel>> watchMyOrders(String userId) {
    return _orders
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(OrderModel.fromDoc).toList());
  }

  /// เวอร์ชันไม่ orderBy (ใช้ดีบักกรณีติด index)
  Stream<List<OrderModel>> watchMyOrdersNoOrder(String userId) {
    return _orders
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map(OrderModel.fromDoc).toList());
  }

  /// สำหรับแอดมิน: ดูทั้งหมด (กรองสถานะได้)
  Stream<List<OrderModel>> watchAll({OrderStatus? status}) {
    Query<Map<String, dynamic>> q =
        _orders.orderBy('createdAt', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.snapshots().map((s) => s.docs.map(OrderModel.fromDoc).toList());
  }

  /// สำหรับผู้ใช้: ดึงเฉพาะสถานะที่ต้องการ
  Stream<List<OrderModel>> watchMyByStatus(String userId, OrderStatus status) {
    // *อาจต้อง Composite Index: where(userId) + where(status) + orderBy(createdAt)
    return _orders
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(OrderModel.fromDoc).toList());
  }

  /// ---------- Update ----------
  /// อัปเดตสถานะ (เช็ค transition + เขียน timeline)
  Future<void> updateStatus(String orderId, OrderStatus to,
      {String? cancelReason}) async {
    final ref = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('ไม่พบคำสั่งซื้อ');

      final data = snap.data()!;
      final cur = _fromStr((data['status'] ?? 'pending').toString());

      if (!_isValidTransition(cur, to)) {
        throw Exception('เปลี่ยนสถานะไม่ได้: ${cur.name} → ${to.name}');
      }

      // อัปเดตสถานะ + เวลา
      tx.update(ref, {
        'status': to.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (to == OrderStatus.cancelled) 'cancelReason': cancelReason ?? '—',
      });

      // เพิ่ม timeline: หลีกเลี่ยง serverTimestamp ภายใน array
      final timeline = (data['timeline'] as List?) ?? [];
      timeline.add({'status': to.name, 'at': Timestamp.now()});
      tx.update(ref, {'timeline': timeline});
    });
  }

  /// ผู้ใช้ยกเลิกออเดอร์ตัวเอง (ได้เฉพาะสถานะที่ยังยกเลิกได้)
  Future<void> cancelMyOrder(String orderId, String userId,
      {String reason = 'ผู้ใช้ยกเลิก'}) async {
    final ref = _orders.doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('ไม่พบคำสั่งซื้อ');

      final data = snap.data()!;
      if (data['userId'] != userId) {
        throw Exception('ไม่มีสิทธิ์ยกเลิกออเดอร์นี้');
      }

      final cur = _fromStr((data['status'] ?? 'pending').toString());
      // อนุญาตให้ผู้ใช้ยกเลิกเฉพาะช่วง early: pending / paid / preparing
      final canCancel = {
        OrderStatus.pending,
        OrderStatus.paid,
        OrderStatus.preparing
      }.contains(cur);
      if (!canCancel) throw Exception('ไม่สามารถยกเลิกในสถานะปัจจุบันได้');

      tx.update(ref, {
        'status': OrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
      });

      final timeline = (data['timeline'] as List?) ?? [];
      timeline
          .add({'status': OrderStatus.cancelled.name, 'at': Timestamp.now()});
      tx.update(ref, {'timeline': timeline});
    });
  }
}
