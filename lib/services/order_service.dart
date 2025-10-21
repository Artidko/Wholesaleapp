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

  /* =================== Helpers =================== */
  OrderStatus _fromStr(String s) {
    try {
      return OrderStatus.values.byName(s);
    } catch (_) {
      return OrderStatus.pending;
    }
  }

  bool _isValidTransition(OrderStatus from, OrderStatus to) {
    // Flow: pending -> paid -> preparing -> delivering -> completed (+ cancelled)
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

  /* =================== Create =================== */
  /// ต้องส่ง destLat/destLng ด้วย และ **ต้องมี userId** ให้ผ่านกฎ Firestore
  Future<String> createOrderFromCart({
    required CartProvider cart,
    required String addressText,
    required String paymentText,
    required double destLat,
    required double destLng,
    num shippingFee = 0,
    bool markPaid = true, // COD = true, PromptPay = false
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('ต้องล็อกอินก่อนทำรายการสั่งซื้อ');
    }
    if (cart.isEmpty) {
      throw Exception('ตะกร้าว่าง ไม่สามารถสร้างออเดอร์ได้');
    }

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

    final ref = _orders.doc(); // สร้าง id ล่วงหน้า
    final data = {
      'id': ref.id,
      'userId': user.uid, // <<< สำคัญ
      'lines': lines.map((e) => e.toMap()).toList(),
      'subTotal': subTotal,
      'shippingFee': shippingFee,
      'grandTotal': grandTotal,
      'addressText': addressText,
      'paymentText': paymentText,
      'status': initialStatus.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'dest': {'lat': destLat, 'lng': destLng},
      'trackingActive': false,
      'timeline': [
        {'status': initialStatus.name, 'at': Timestamp.now()},
      ],
      // ให้ว่างไว้ก่อน ลูกค้าจะมาแนบสลิปทีหลัง
      'payment': null,
      'statusClientNote': null,
    };

    await ref.set(data);
    cart.clear();
    return ref.id;
  }

  /* =================== Read =================== */
  Future<OrderModel> getOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    if (!doc.exists) throw Exception('ไม่พบคำสั่งซื้อ');
    return OrderModel.fromDoc(doc);
  }

  Stream<OrderModel> watchOrder(String orderId) =>
      _orders.doc(orderId).snapshots().map(OrderModel.fromDoc);

  Stream<List<OrderModel>> watchMyOrders(String userId) => _orders
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(OrderModel.fromDoc).toList());

  Stream<List<OrderModel>> watchAll({OrderStatus? status}) {
    Query<Map<String, dynamic>> q =
        _orders.orderBy('createdAt', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.snapshots().map((s) => s.docs.map(OrderModel.fromDoc).toList());
  }

  /* =================== Update (status) =================== */
  Future<void> updateStatus(
    String orderId,
    OrderStatus to, {
    String? cancelReason,
    bool force = false,
  }) async {
    final ref = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('ไม่พบคำสั่งซื้อ');

      final data = snap.data()!;
      final cur = _fromStr((data['status'] ?? 'pending').toString());
      if (!force && !_isValidTransition(cur, to)) {
        throw Exception('เปลี่ยนสถานะไม่ได้: ${cur.name} → ${to.name}');
      }

      tx.update(ref, {
        'status': to.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (to == OrderStatus.cancelled) 'cancelReason': cancelReason ?? '—',
      });

      final timeline = (data['timeline'] as List?) ?? [];
      timeline.add({'status': to.name, 'at': Timestamp.now()});
      tx.update(ref, {'timeline': timeline});
    });
  }

  Future<void> adminUpdateStatus(
    String orderId,
    OrderStatus to, {
    String? cancelReason,
  }) =>
      updateStatus(orderId, to, cancelReason: cancelReason, force: true);

  Future<void> cancelMyOrder(
    String orderId,
    String userId, {
    String reason = 'ผู้ใช้ยกเลิก',
  }) async {
    final ref = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('ไม่พบคำสั่งซื้อ');

      final data = snap.data()!;
      if (data['userId'] != userId) {
        throw Exception('ไม่มีสิทธิ์ยกเลิกออเดอร์นี้');
      }

      final cur = _fromStr((data['status'] ?? 'pending').toString());
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

  /* =================== Payment helpers =================== */
  /// ลูกค้าแนบสลิป: อัปเดตเฉพาะคีย์ที่กฎอนุญาต (payment + statusClientNote)
  Future<void> attachPaymentSlip({
    required String orderId,
    required String slipUrl,
    required String note, // ข้อความแจ้งลูกค้า
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _orders.doc(orderId).set({
      'payment': {
        'method': 'promptpay',
        'slipUrl': slipUrl,
        'submittedBy': uid,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewStatus': 'pending',
      },
      'statusClientNote': note,
    }, SetOptions(merge: true));
  }

  /// แอดมินอนุมัติ/ปฏิเสธสลิป
  Future<void> adminReviewSlip({
    required String orderId,
    required bool approve,
    String? rejectReason,
    bool setPaidWhenApprove = true,
  }) async {
    final updates = <String, dynamic>{
      'payment.reviewStatus': approve ? 'approved' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
      if (!approve) 'statusClientNote': rejectReason ?? 'แอดมินปฏิเสธสลิป',
    };
    if (approve && setPaidWhenApprove) {
      updates['status'] = 'paid';
      // (จะไม่ตรวจ flow เพราะฝั่งแอดมินมีสิทธิ์เต็มอยู่แล้ว)
    }
    await _orders.doc(orderId).update(updates);
  }

  /* =================== Driver helpers =================== */
  Future<void> setDriver(String orderId, String driverId) async {
    await _orders.doc(orderId).set({
      'driverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setTrackingActive(
    String orderId,
    bool active, {
    String? sessionId,
  }) async {
    await _orders.doc(orderId).set({
      'trackingActive': active,
      if (sessionId != null) 'current': {'sessionId': sessionId},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCurrentLocation(
    String orderId, {
    required double lat,
    required double lng,
    double? speed,
    double? heading,
    double? acc,
  }) async {
    await _orders.doc(orderId).set({
      'current': {
        'lat': lat,
        'lng': lng,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (acc != null) 'acc': acc,
        'ts': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watchRider(String orderId) {
    return _orders.doc(orderId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return null;
      final r = data['rider'];
      return (r is Map<String, dynamic>) ? r : null;
    });
  }
}
