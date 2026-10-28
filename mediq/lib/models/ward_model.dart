import 'package:cloud_firestore/cloud_firestore.dart';

class WardModel {
  final String id;
  final String wardName;
  final String team;
  final String managedBy;
  final String category;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WardModel({
    required this.id,
    required this.wardName,
    this.team = '',
    this.managedBy = '',
    this.category = '',
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  factory WardModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return WardModel.fromMap(data, doc.id);
  }

  factory WardModel.fromMap(Map<String, dynamic> data, String id) {
    return WardModel(
      id: id,
      wardName: data['wardName'] ?? '',
      team: data['team'] ?? '',
      managedBy: data['managedBy'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
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
      'wardName': wardName,
      'team': team,
      'managedBy': managedBy,
      'category': category,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  WardModel copyWith({
    String? id,
    String? wardName,
    String? team,
    String? managedBy,
    String? category,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WardModel(
      id: id ?? this.id,
      wardName: wardName ?? this.wardName,
      team: team ?? this.team,
      managedBy: managedBy ?? this.managedBy,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
