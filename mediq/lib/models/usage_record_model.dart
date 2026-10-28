import 'package:cloud_firestore/cloud_firestore.dart';

class UsageRecordModel {
  final String id;
  final String antibioticId;
  final String antibioticName;
  final String dosage;
  final String wardId;
  final String wardName;
  final DateTime dateTime;
  final String pageNumber;
  final String bookNumber;
  final int itemCount;
  final String stockType;
  final String? createdBy;
  final DateTime? createdAt;
  final bool isReturn;

  const UsageRecordModel({
    required this.id,
    required this.antibioticId,
    required this.antibioticName,
    required this.dosage,
    required this.wardId,
    required this.wardName,
    required this.dateTime,
    this.pageNumber = '',
    this.bookNumber = '',
    this.itemCount = 0,
    this.stockType = 'Main Stock',
    this.createdBy,
    this.createdAt,
    this.isReturn = false,
  });

  factory UsageRecordModel.fromFirestore(DocumentSnapshot doc, {bool isReturn = false}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UsageRecordModel.fromMap(data, doc.id, isReturn: isReturn);
  }

  factory UsageRecordModel.fromMap(
    Map<String, dynamic> data,
    String id, {
    bool isReturn = false,
  }) {
    DateTime parsedDate = DateTime.now();
    final rawDate = isReturn ? data['returnDateTime'] : data['releaseDateTime'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return UsageRecordModel(
      id: id,
      antibioticId: data['antibioticId'] ?? '',
      antibioticName: data['antibioticName'] ?? '',
      dosage: data['dosage'] ?? '',
      wardId: data['wardId'] ?? '',
      wardName: data['wardName'] ?? '',
      dateTime: parsedDate,
      pageNumber: data['pageNumber'] ?? '',
      bookNumber: data['bookNumber'] ?? '',
      itemCount: (data['itemCount'] is num) ? (data['itemCount'] as num).toInt() : 0,
      stockType: data['stockType'] ?? (isReturn ? 'Return Stock' : 'Main Stock'),
      createdBy: data['createdBy'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['createdAt'].toString()))
          : null,
      isReturn: isReturn,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'antibioticId': antibioticId,
      'antibioticName': antibioticName,
      'dosage': dosage,
      'wardId': wardId,
      'wardName': wardName,
      isReturn ? 'returnDateTime' : 'releaseDateTime': dateTime,
      'pageNumber': pageNumber,
      'bookNumber': bookNumber,
      'itemCount': itemCount,
      'stockType': stockType,
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
