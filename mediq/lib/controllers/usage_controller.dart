import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usage_record_model.dart';

class UsageController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _releasesCollection => _firestore.collection('releases');
  CollectionReference get _returnsCollection => _firestore.collection('returns');

  /// Stream releases with optional limit
  Stream<List<UsageRecordModel>> streamReleases({int? limit}) {
    Query query = _releasesCollection.orderBy('releaseDateTime', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => UsageRecordModel.fromFirestore(doc, isReturn: false))
        .toList());
  }

  /// Stream returns with optional limit
  Stream<List<UsageRecordModel>> streamReturns({int? limit}) {
    Query query = _returnsCollection.orderBy('returnDateTime', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => UsageRecordModel.fromFirestore(doc, isReturn: true))
        .toList());
  }

  /// Stream releases for a specific month
  Stream<List<UsageRecordModel>> streamReleasesForMonth({
    required String antibioticId,
    required DateTime startOfMonth,
    required DateTime endOfMonth,
  }) {
    return _releasesCollection
        .where('antibioticId', isEqualTo: antibioticId)
        .where('releaseDateTime', isGreaterThanOrEqualTo: startOfMonth)
        .where('releaseDateTime', isLessThan: endOfMonth)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UsageRecordModel.fromFirestore(doc, isReturn: false))
            .toList());
  }

  /// Execute an atomic transaction to release antibiotics and deduct from main_stock
  Future<void> releaseAntibiotic({
    required String antibioticId,
    required String antibioticName,
    required String dosage,
    required int dosageIndex,
    required String wardId,
    required String wardName,
    required DateTime releaseDateTime,
    required String pageNumber,
    required String bookNumber,
    required int itemCount,
    required String stockType,
    required String userId,
  }) async {
    final stockQuery = await _firestore
        .collection('main_stock')
        .where('antibioticId', isEqualTo: antibioticId)
        .where('dosageIndex', isEqualTo: dosageIndex)
        .limit(1)
        .get();

    if (stockQuery.docs.isEmpty) {
      throw Exception('No stock entry found for this antibiotic and dosage');
    }

    final stockDoc = stockQuery.docs.first;

    await _firestore.runTransaction((transaction) async {
      final freshStockDoc = await transaction.get(stockDoc.reference);
      if (!freshStockDoc.exists) {
        throw Exception('Stock document no longer exists');
      }

      final freshData = freshStockDoc.data() as Map<String, dynamic>;
      final freshQuantity = freshData['quantity'] as int? ?? 0;

      if (freshQuantity < itemCount) {
        throw Exception('Insufficient stock. Available: $freshQuantity');
      }

      transaction.update(stockDoc.reference, {
        'quantity': freshQuantity - itemCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      final releaseRef = _releasesCollection.doc();
      transaction.set(releaseRef, {
        'antibioticId': antibioticId,
        'antibioticName': antibioticName,
        'dosage': dosage,
        'wardId': wardId,
        'wardName': wardName,
        'releaseDateTime': releaseDateTime,
        'pageNumber': pageNumber,
        'bookNumber': bookNumber,
        'itemCount': itemCount,
        'stockType': stockType,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Execute an atomic transaction to return antibiotics and add to return_stock
  Future<void> returnAntibiotic({
    required String antibioticId,
    required String antibioticName,
    required String dosage,
    required int dosageIndex,
    required String wardId,
    required String wardName,
    required DateTime returnDateTime,
    required String pageNumber,
    required String bookNumber,
    required int itemCount,
    required String stockType,
    required String userId,
  }) async {
    final stockQuery = await _firestore
        .collection('return_stock')
        .where('antibioticId', isEqualTo: antibioticId)
        .where('dosageIndex', isEqualTo: dosageIndex)
        .limit(1)
        .get();

    await _firestore.runTransaction((transaction) async {
      if (stockQuery.docs.isNotEmpty) {
        final stockDoc = stockQuery.docs.first;
        final freshStockDoc = await transaction.get(stockDoc.reference);
        final freshData = freshStockDoc.data() as Map<String, dynamic>;
        final currentQuantity = freshData['quantity'] as int? ?? 0;

        transaction.update(stockDoc.reference, {
          'quantity': currentQuantity + itemCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final newStockRef = _firestore.collection('return_stock').doc();
        transaction.set(newStockRef, {
          'antibioticId': antibioticId,
          'dosageIndex': dosageIndex,
          'srNumber': '',
          'drugName': antibioticName,
          'dosage': dosage,
          'quantity': itemCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      final returnRef = _returnsCollection.doc();
      transaction.set(returnRef, {
        'antibioticId': antibioticId,
        'antibioticName': antibioticName,
        'dosage': dosage,
        'wardId': wardId,
        'wardName': wardName,
        'returnDateTime': returnDateTime,
        'pageNumber': pageNumber,
        'bookNumber': bookNumber,
        'itemCount': itemCount,
        'stockType': stockType,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
