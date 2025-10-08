import 'package:cloud_firestore/cloud_firestore.dart';

/// ประเภทวิธีชำระเงิน
enum PaymentType { cod, promptpay, bankTransfer }

class PaymentMethodItem {
  final String id;
  final String label;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ฟิลด์ใหม่สำหรับ 3 วิธี
  final PaymentType type;
  final String? promptPayId; // ใช้กับ promptpay
  final String? bankName; // ใช้กับ bankTransfer
  final String? bankAccount; // ใช้กับ bankTransfer
  final String? bankAccountName; // ใช้กับ bankTransfer

  PaymentMethodItem({
    this.id = '',
    required this.label,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
    this.type = PaymentType.cod,
    this.promptPayId,
    this.bankName,
    this.bankAccount,
    this.bankAccountName,
  });

  PaymentMethodItem copyWith({
    String? id,
    String? label,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    PaymentType? type,
    String? promptPayId,
    String? bankName,
    String? bankAccount,
    String? bankAccountName,
  }) {
    return PaymentMethodItem(
      id: id ?? this.id,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      promptPayId: promptPayId ?? this.promptPayId,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }

  /// แปลงเป็น Map เพื่อบันทึก Firestore
  Map<String, dynamic> toMap() => {
        'label': label,
        'isDefault': isDefault,
        'type': _typeToString(type),
        if (promptPayId != null) 'promptPayId': promptPayId,
        if (bankName != null) 'bankName': bankName,
        if (bankAccount != null) 'bankAccount': bankAccount,
        if (bankAccountName != null) 'bankAccountName': bankAccountName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// อ่านจาก Firestore (รองรับเอกสารเก่าที่ไม่มี type)
  static PaymentMethodItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final t = _parseType(d['type']);
    return PaymentMethodItem(
      id: doc.id,
      label: d['label'] ?? '',
      isDefault: (d['isDefault'] ?? false) as bool,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      type: t,
      promptPayId: d['promptPayId'],
      bankName: d['bankName'],
      bankAccount: d['bankAccount'],
      bankAccountName: d['bankAccountName'],
    );
  }

  // ===== helpers =====
  static PaymentType _parseType(dynamic v) {
    switch (v) {
      case 'promptpay':
        return PaymentType.promptpay;
      case 'bankTransfer':
        return PaymentType.bankTransfer;
      case 'cod':
      default:
        // ถ้าเอกสารเก่าไม่มีฟิลด์ type ให้เป็น COD
        return PaymentType.cod;
    }
  }

  static String _typeToString(PaymentType t) {
    switch (t) {
      case PaymentType.cod:
        return 'cod';
      case PaymentType.promptpay:
        return 'promptpay';
      case PaymentType.bankTransfer:
        return 'bankTransfer';
    }
  }
}
