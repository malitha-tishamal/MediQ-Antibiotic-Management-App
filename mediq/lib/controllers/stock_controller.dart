import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_model.dart';

class StockController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _mainStockCollection =>
      _firestore.collection('main_stock');
  CollectionReference get _returnStockCollection =>
      _firestore.collection('return_stock');

  /// Stream of main store stock items
  Stream<List<StockItemModel>> streamMainStock() {
    return _mainStockCollection
        .orderBy('drugName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockItemModel.fromFirestore(doc))
            .toList());
  }

  /// Stream of return store stock items
  Stream<List<StockItemModel>> streamReturnStock() {
    return _returnStockCollection
        .orderBy('drugName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockItemModel.fromFirestore(doc))
            .toList());
  }

  /// Update stock quantity
  Future<void> updateStockQuantity({
    required String collectionName,
    required String docId,
    required int newQuantity,
  }) async {
    await _firestore.collection(collectionName).doc(docId).update({
      'quantity': newQuantity,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Add new stock item
  Future<DocumentReference> addStockItem({
    required String collectionName,
    required StockItemModel item,
  }) async {
    return await _firestore.collection(collectionName).add(item.toMap());
  }

  /// Delete stock item
  Future<void> deleteStockItem({
    required String collectionName,
    required String docId,
  }) async {
    await _firestore.collection(collectionName).doc(docId).delete();
  }
}
