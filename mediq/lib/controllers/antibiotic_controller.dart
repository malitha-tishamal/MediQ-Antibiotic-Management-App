import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/antibiotic_model.dart';

class AntibioticController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _antibioticsCollection =>
      _firestore.collection('antibiotics');

  /// Stream of all antibiotics
  Stream<List<AntibioticModel>> streamAntibiotics() {
    return _antibioticsCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AntibioticModel.fromFirestore(doc))
            .toList());
  }

  /// Get single antibiotic by ID
  Future<AntibioticModel?> getAntibioticById(String id) async {
    final doc = await _antibioticsCollection.doc(id).get();
    if (!doc.exists) return null;
    return AntibioticModel.fromFirestore(doc);
  }

  /// Add new antibiotic
  Future<DocumentReference> addAntibiotic(AntibioticModel antibiotic) async {
    final data = antibiotic.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    return await _antibioticsCollection.add(data);
  }

  /// Update existing antibiotic
  Future<void> updateAntibiotic(AntibioticModel antibiotic) async {
    await _antibioticsCollection.doc(antibiotic.id).update(antibiotic.toMap());
  }

  /// Delete antibiotic
  Future<void> deleteAntibiotic(String id) async {
    await _antibioticsCollection.doc(id).delete();
  }
}
