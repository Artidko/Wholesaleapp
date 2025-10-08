// lib/services/product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductService {
  ProductService._();
  static final instance = ProductService._();

  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('products');

  /// ใช้กับโค้ดเดิมใน CatalogTab
  Stream<List<Product>> watch() => watchAll();

  /// ดูทั้งหมด (เรียงล่าสุดก่อน)
  Stream<List<Product>> watchAll() {
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
        );
  }

  /// ดูตามหมวด:
  /// - ถ้า category ว่าง/“ทั้งหมด” => เรียงตาม updatedAt (ไม่ต้องมี index พิเศษ)
  /// - ถ้ามีการกรองหมวด => ตัด orderBy ออก (แก้ปัญหา needs index ชั่วคราว)
  ///   *หลังสร้าง Composite Index แล้ว ค่อยเปิด orderBy กลับได้*
  Stream<List<Product>> watchByCategory(String? category) {
    final filter =
        category != null && category.isNotEmpty && category != 'ทั้งหมด';

    Query<Map<String, dynamic>> q = _col;
    if (filter) {
      q = q.where('category', isEqualTo: category);
      // ❗ ชั่วคราวไม่ใส่ orderBy เพื่อตัด requirement index
      return q.snapshots().map(
        (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
      );
    }

    // ไม่กรองหมวด => เรียงตาม updatedAt
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
        );
  }

  /// เวอร์ชันดีบัก: ไม่ orderBy + พิมพ์จำนวนเอกสาร
  Stream<List<Product>> watchDebug() {
    return _col.snapshots().map((s) {
      // ignore: avoid_print
      print('📦 products docs: ${s.docs.length}');
      return s.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    });
  }

  /// ค้นหาตามข้อความ (ชื่อ/sku) + ตัวเลือกหมวด
  Stream<List<Product>> search({required String query, String? category}) {
    return watchByCategory(category).map((list) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return list;
      return list
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                (p.sku ?? '').toLowerCase().contains(q),
          )
          .toList();
    });
  }

  /// เพิ่ม/อัปเดตสินค้าแบบเต็ม
  Future<void> upsert(Product p, {bool useServerTime = true}) async {
    await _col
        .doc(p.id)
        .set(p.toMap(useServerTime: useServerTime), SetOptions(merge: true));
  }

  /// อัปเดตเฉพาะรูป
  Future<void> updateImageUrl({
    required String productId,
    required String imageUrl,
  }) async {
    await _col.doc(productId).update({
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ลบสินค้า
  Future<void> delete(String productId) => _col.doc(productId).delete();

  /// เพิ่มสินค้าทดสอบ (มี category)
  Future<void> seedDemo() async {
    await _col.add({
      'name': 'สินค้าทดสอบ',
      'price': 19.0,
      'imageUrl': 'https://picsum.photos/seed/demo/300/300',
      'sku': 'DEMO-001',
      'stock': 10,
      'category': 'เครื่องดื่ม',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
