// lib/models/order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// 1) รายการสินค้าในออเดอร์ (หนึ่งบรรทัดต่อหนึ่งสินค้า)
class OrderLine {
  final String productId;
  final String name;
  final String imageUrl;
  final int qty;
  final num price; // ราคาต่อชิ้น ณ เวลาสั่ง

  const OrderLine({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.price,
  });

  num get lineTotal => price * qty;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'qty': qty,
        'price': price,
        'lineTotal': lineTotal,
      };

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
        productId: (m['productId'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        imageUrl: (m['imageUrl'] ?? '').toString(),
        qty: (m['qty'] is int)
            ? m['qty']
            : int.tryParse('${m['qty'] ?? 0}') ?? 0,
        price: (m['price'] is num)
            ? m['price']
            : num.tryParse('${m['price'] ?? 0}') ?? 0,
      );
}

/// 2) สถานะคำสั่งซื้อ (อิงตามที่คุณกำหนด)
enum OrderStatus { pending, paid, preparing, delivering, completed, cancelled }

OrderStatus _statusFromString(String s) {
  try {
    return OrderStatus.values.byName(s);
  } catch (_) {
    return OrderStatus.pending;
  }
}

String statusToString(OrderStatus s) => s.name;

/// Helper: ป้ายภาษาไทย + สี (ใช้ใน UI)
extension OrderStatusX on OrderStatus {
  String get labelTh => switch (this) {
        OrderStatus.pending => 'รอชำระ/สร้างออเดอร์',
        OrderStatus.paid => 'ชำระเงินแล้ว',
        OrderStatus.preparing => 'กำลังเตรียม',
        OrderStatus.delivering => 'กำลังจัดส่ง',
        OrderStatus.completed => 'เสร็จสิ้น',
        OrderStatus.cancelled => 'ยกเลิก',
      };

  /// RGB สำหรับป้ายสถานะ
  (int r, int g, int b) get rgb => switch (this) {
        OrderStatus.pending => (158, 158, 158),
        OrderStatus.paid => (33, 150, 243),
        OrderStatus.preparing => (0, 150, 136),
        OrderStatus.delivering => (255, 152, 0),
        OrderStatus.completed => (76, 175, 80),
        OrderStatus.cancelled => (244, 67, 54),
      };
}

/// 3) โมเดลออเดอร์หลัก
class OrderModel {
  final String id;
  final String userId;
  final List<OrderLine> lines;
  final num subTotal;
  final num shippingFee;
  final num grandTotal;

  /// เก็บสรุปที่อยู่จัดส่ง/วิธีชำระเงินเป็นข้อความ พร้อมแสดงใน UI ได้ทันที
  final String addressText;
  final String paymentText;

  final OrderStatus status;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.lines,
    required this.subTotal,
    required this.shippingFee,
    required this.grandTotal,
    required this.addressText,
    required this.paymentText,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'lines': lines.map((e) => e.toMap()).toList(),
        'subTotal': subTotal,
        'shippingFee': shippingFee,
        'grandTotal': grandTotal,
        'addressText': addressText,
        'paymentText': paymentText,
        'status': statusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    final List raw = (m['lines'] ?? []) as List;

    return OrderModel(
      id: doc.id,
      userId: (m['userId'] ?? '').toString(),
      lines: raw
          .map((e) => OrderLine.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      subTotal: (m['subTotal'] is num)
          ? m['subTotal']
          : num.tryParse('${m['subTotal'] ?? 0}') ?? 0,
      shippingFee: (m['shippingFee'] is num)
          ? m['shippingFee']
          : num.tryParse('${m['shippingFee'] ?? 0}') ?? 0,
      grandTotal: (m['grandTotal'] is num)
          ? m['grandTotal']
          : num.tryParse('${m['grandTotal'] ?? 0}') ?? 0,
      addressText: (m['addressText'] ?? '').toString(),
      paymentText: (m['paymentText'] ?? '').toString(),
      status: _statusFromString((m['status'] ?? 'pending').toString()),
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    List<OrderLine>? lines,
    num? subTotal,
    num? shippingFee,
    num? grandTotal,
    String? addressText,
    String? paymentText,
    OrderStatus? status,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lines: lines ?? this.lines,
      subTotal: subTotal ?? this.subTotal,
      shippingFee: shippingFee ?? this.shippingFee,
      grandTotal: grandTotal ?? this.grandTotal,
      addressText: addressText ?? this.addressText,
      paymentText: paymentText ?? this.paymentText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
