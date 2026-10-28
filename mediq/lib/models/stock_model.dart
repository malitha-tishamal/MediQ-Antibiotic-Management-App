import 'package:cloud_firestore/cloud_firestore.dart';

class StockItemModel {
  final String id;
  final String srNumber;
  final String drugName;
  final String dosage;
  final int quantity;
  final DateTime? lastUpdated;

  const StockItemModel({
    required this.id,
    required this.srNumber,
    required this.drugName,
    required this.dosage,
    this.quantity = 0,
    this.lastUpdated,
  });

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity < 50;
  bool get isInStock => quantity >= 50;

  factory StockItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return StockItemModel.fromMap(data, doc.id);
  }

  factory StockItemModel.fromMap(Map<String, dynamic> data, String id) {
    int parsedQty = 0;
    final q = data['quantity'];
    if (q is int) {
      parsedQty = q;
    } else if (q is num) {
      parsedQty = q.toInt();
    } else if (q is String) {
      parsedQty = int.tryParse(q) ?? 0;
    }

    return StockItemModel(
      id: id,
      srNumber: data['srNumber'] ?? '',
      drugName: data['drugName'] ?? data['antibioticName'] ?? '',
      dosage: data['dosage'] ?? '',
      quantity: parsedQty,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] is Timestamp
              ? (data['lastUpdated'] as Timestamp).toDate()
              : DateTime.tryParse(data['lastUpdated'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'srNumber': srNumber,
      'drugName': drugName,
      'dosage': dosage,
      'quantity': quantity,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  StockItemModel copyWith({
    String? id,
    String? srNumber,
    String? drugName,
    String? dosage,
    int? quantity,
    DateTime? lastUpdated,
  }) {
    return StockItemModel(
      id: id ?? this.id,
      srNumber: srNumber ?? this.srNumber,
      drugName: drugName ?? this.drugName,
      dosage: dosage ?? this.dosage,
      quantity: quantity ?? this.quantity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
