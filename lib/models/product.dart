// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String? sku;
  final int? stock;
  final DateTime? updatedAt;
  final String? category; // ✅ เพิ่มฟิลด์หมวดสินค้า

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.sku,
    this.stock,
    this.updatedAt,
    this.category, // ✅ ใหม่
  });

  /// ใช้ตอนอ่านจาก Firestore: Product.fromMap(doc.id, doc.data())
  factory Product.fromMap(String id, Map<String, dynamic> m) {
    return Product(
      id: id,
      name: (m['name'] ?? '') as String,
      price: _toDouble(m['price']),
      imageUrl: (m['imageUrl'] ?? '') as String,
      sku: m['sku'] as String?,
      stock: (m['stock'] as num?)?.toInt(),
      updatedAt: _toDate(m['updatedAt']),
      category: m['category'] as String?, // ✅ ใหม่
    );
  }

  /// ใช้ตอนจะเขียนกลับ Firestore
  Map<String, dynamic> toMap({bool useServerTime = false}) {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'sku': sku,
      'stock': stock,
      'category': category, // ✅ ใหม่
      'updatedAt': useServerTime
          ? FieldValue.serverTimestamp()
          : (updatedAt != null ? Timestamp.fromDate(updatedAt!) : null),
    }..removeWhere((k, v) => v == null);
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? sku,
    int? stock,
    DateTime? updatedAt,
    String? category, // ✅ ใหม่
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      stock: stock ?? this.stock,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  // --- Helpers ---
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // รองรับทั้ง seconds และ milliseconds
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) {
      // ISO8601
      return DateTime.tryParse(v);
    }
    return null;
  }
}
