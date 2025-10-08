// lib/services/user_settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address_item.dart';
import '../models/payment_method_item.dart';

class UserSettingsService {
  UserSettingsService._();
  static final instance = UserSettingsService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    }
    return u.uid;
  }

  /* ==================== PROFILE ==================== */

  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
  }) async {
    final ref = _db.collection('users').doc(_uid);
    await ref.set({
      'profile': {
        'name': name,
        'email': email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> profileStream() {
    final ref = _db.collection('users').doc(_uid);
    return ref.snapshots().map((d) {
      if (!d.exists) return null;
      final map = d.data();
      return (map?['profile'] as Map<String, dynamic>?) ?? {};
    });
  }

  /* ==================== ADDRESSES (ต่อผู้ใช้) ==================== */

  CollectionReference<Map<String, dynamic>> get _addrCol =>
      _db.collection('users').doc(_uid).collection('addresses');

  Stream<List<AddressItem>> addressesStream() {
    return _addrCol
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((doc) {
              final data = doc.data();
              return AddressItem(
                id: doc.id,
                fullName: data['fullName'] ?? '',
                line1: data['line1'] ?? '',
                line2: data['line2'] ?? '',
                city: data['city'] ?? '',
                zip: data['zip'] ?? '',
                isDefault: data['isDefault'] ?? false,
                updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList());
  }

  Future<String> upsertAddress(AddressItem item, {String? id}) async {
    final doc = (id == null || id.isEmpty) ? _addrCol.doc() : _addrCol.doc(id);
    final data = {
      'fullName': item.fullName,
      'line1': item.line1,
      'line2': item.line2,
      'city': item.city,
      'zip': item.zip,
      'isDefault': item.isDefault,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await doc.set(data, SetOptions(merge: true));
    return doc.id;
  }

  Future<void> deleteAddress(String id) => _addrCol.doc(id).delete();

  Future<void> setDefaultAddress(String id) async {
    final qs = await _addrCol.get();
    if (qs.docs.isEmpty) return;

    final hasId = qs.docs.any((d) => d.id == id);
    if (!hasId) {
      throw Exception('ไม่พบที่อยู่ที่ต้องการตั้งเป็นค่าเริ่มต้น');
    }

    final batch = _db.batch();
    for (final d in qs.docs) {
      final shouldBe = d.id == id;
      final current = (d.data()['isDefault'] as bool?) ?? false;
      if (current != shouldBe) {
        batch.update(d.reference, {
          'isDefault': shouldBe,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<AddressItem?> getDefaultAddress() async {
    final qs =
        await _addrCol.where('isDefault', isEqualTo: true).limit(1).get();
    if (qs.docs.isEmpty) return null;
    return AddressItem.fromDoc(qs.docs.first);
  }

  /* ========== GLOBAL PAYMENT METHODS (ไม่ผูกผู้ใช้) ========== */

  /// คอลเลกชันกลางของวิธีชำระเงิน
  CollectionReference<Map<String, dynamic>> get _globalPayCol =>
      _db.collection('payment_methods');

  /// สตรีมวิธีชำระเงินแบบ Global (เปิดใช้งานเท่านั้น) เรียงตาม priority
  /// ⚠️ ต้องมี Composite Index: `payment_methods` → enabled(Asc), priority(Asc)
  Stream<List<PaymentMethodItem>> paymentsStream() => _globalPayCol
      .where('enabled', isEqualTo: true)
      .orderBy('priority')
      .snapshots()
      .map((qs) => qs.docs.map(PaymentMethodItem.fromDoc).toList());

  /// เพิ่ม/แก้ไขวิธีชำระเงินในคอลเลกชันกลาง
  Future<String> upsertPayment(PaymentMethodItem item, {String? id}) async {
    final doc = (id == null || id.isEmpty)
        ? _globalPayCol.doc()
        : _globalPayCol.doc(id);
    final data = {
      ...item.toMap(),
      'enabled': true, // ค่าเริ่มต้น
      'priority': (item.toMap()['priority'] ?? 999),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDefault': (item.isDefault == true),
    };
    await doc.set(data, SetOptions(merge: true));
    return doc.id;
  }

  Future<void> deletePayment(String id) => _globalPayCol.doc(id).delete();

  /// ตั้ง default ในคอลเลกชันกลางให้เหลือ 1 รายการ
  Future<void> setDefaultPayment(String id) async {
    final qs = await _globalPayCol.get();
    if (qs.docs.isEmpty) return;

    final hasId = qs.docs.any((d) => d.id == id);
    if (!hasId) {
      throw Exception('ไม่พบวิธีชำระเงินที่ต้องการตั้งเป็นค่าเริ่มต้น');
    }

    final batch = _db.batch();
    for (final d in qs.docs) {
      final shouldBe = d.id == id;
      final current = (d.data()['isDefault'] as bool?) ?? false;
      if (current != shouldBe) {
        batch.update(d.reference, {
          'isDefault': shouldBe,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<PaymentMethodItem?> getDefaultPayment() async {
    final qs =
        await _globalPayCol.where('isDefault', isEqualTo: true).limit(1).get();
    if (qs.docs.isEmpty) return null;
    return PaymentMethodItem.fromDoc(qs.docs.first);
  }

  /// ===== Seed วิธีชำระเงิน Global = 2 วิธี (COD / PromptPay) =====
  Future<void> ensureGlobalPaymentMethods() async {
    final snap = await _globalPayCol.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final now = FieldValue.serverTimestamp();

    // 1) เก็บเงินปลายทาง (COD)
    await _globalPayCol.add({
      'label': 'เก็บเงินปลายทาง',
      'type': 'cod',
      'enabled': true,
      'priority': 1,
      'isDefault': true,
      'updatedAt': now,
    });

    // 2) QR พร้อมเพย์ (PromptPay)
    await _globalPayCol.add({
      'label': 'QR พร้อมเพย์',
      'type': 'promptpay',
      'promptPayId': '0812345678', // TODO: เปลี่ยนเป็นของร้านคุณ
      'enabled': true,
      'priority': 2,
      'isDefault': false,
      'updatedAt': now,
    });
  }

  /// (ทางเลือก) ปิดวิธีที่ไม่รองรับให้ไม่โชว์
  Future<void> disableNonSupportedPayments() async {
    final qs = await _globalPayCol
        .where('type', whereIn: ['bankTransfer']) // ปิด bankTransfer ถ้ามี
        .get();
    if (qs.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in qs.docs) {
      batch.update(d.reference, {
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
