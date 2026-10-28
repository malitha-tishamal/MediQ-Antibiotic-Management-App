import 'package:cloud_firestore/cloud_firestore.dart';

class DosageItem {
  final String dosage;
  final String srNumber;

  const DosageItem({
    required this.dosage,
    required this.srNumber,
  });

  factory DosageItem.fromMap(Map<String, dynamic> map) {
    return DosageItem(
      dosage: map['dosage'] ?? '',
      srNumber: map['srNumber'] ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'dosage': dosage,
      'srNumber': srNumber,
    };
  }
}

class AntibioticModel {
  final String id;
  final String name;
  final String category;
  final List<DosageItem> dosages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AntibioticModel({
    required this.id,
    required this.name,
    required this.category,
    this.dosages = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory AntibioticModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AntibioticModel.fromMap(data, doc.id);
  }

  factory AntibioticModel.fromMap(Map<String, dynamic> data, String id) {
    final rawDosages = data['dosages'] as List<dynamic>? ?? [];
    final dosages = rawDosages.map((item) {
      if (item is Map<String, dynamic>) {
        return DosageItem.fromMap(item);
      } else if (item is Map) {
        return DosageItem.fromMap(Map<String, dynamic>.from(item));
      }
      return const DosageItem(dosage: '', srNumber: '');
    }).toList();

    return AntibioticModel(
      id: id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      dosages: dosages,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['createdAt'].toString()))
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['updatedAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'dosages': dosages.map((d) => d.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AntibioticModel copyWith({
    String? id,
    String? name,
    String? category,
    List<DosageItem>? dosages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AntibioticModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      dosages: dosages ?? this.dosages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
