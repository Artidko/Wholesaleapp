import 'package:cloud_firestore/cloud_firestore.dart';

class AddressItem {
  final String id; // Firestore doc id
  final String fullName;
  final String line1;
  final String line2;
  final String city;
  final String zip;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressItem({
    this.id = '',
    required this.fullName,
    required this.line1,
    this.line2 = '',
    required this.city,
    required this.zip,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  AddressItem copyWith({
    String? id,
    String? fullName,
    String? line1,
    String? line2,
    String? city,
    String? zip,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressItem(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      zip: zip ?? this.zip,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'line1': line1,
    'line2': line2,
    'city': city,
    'zip': zip,
    'isDefault': isDefault,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static AddressItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AddressItem(
      id: doc.id,
      fullName: d['fullName'] ?? '',
      line1: d['line1'] ?? '',
      line2: d['line2'] ?? '',
      city: d['city'] ?? '',
      zip: d['zip'] ?? '',
      isDefault: d['isDefault'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
