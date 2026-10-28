import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ward_model.dart';

class WardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _wardsCollection => _firestore.collection('wards');

  /// Stream of all wards
  Stream<List<WardModel>> streamWards() {
    return _wardsCollection
        .orderBy('wardName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => WardModel.fromFirestore(doc)).toList());
  }

  /// Get single ward by ID
  Future<WardModel?> getWardById(String id) async {
    final doc = await _wardsCollection.doc(id).get();
    if (!doc.exists) return null;
    return WardModel.fromFirestore(doc);
  }

  /// Add new ward
  Future<DocumentReference> addWard(WardModel ward) async {
    final data = ward.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    return await _wardsCollection.add(data);
  }

  /// Update existing ward
  Future<void> updateWard(WardModel ward) async {
    await _wardsCollection.doc(ward.id).update(ward.toMap());
  }

  /// Delete ward
  Future<void> deleteWard(String id) async {
    await _wardsCollection.doc(id).delete();
  }
}
