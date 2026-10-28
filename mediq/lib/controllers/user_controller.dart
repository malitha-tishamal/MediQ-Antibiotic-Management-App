import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Stream of users filtered by role
  Stream<List<UserModel>> streamUsersByRole(String role) {
    return _usersCollection
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  /// Update user account status (Approved, Disabled, Pending)
  Future<void> updateUserStatus(String uid, UserStatus status) async {
    await _usersCollection.doc(uid).update({
      'status': status.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update user profile details
  Future<void> updateUserDetails({
    required String uid,
    required String fullName,
    required String mobile,
    required String nic,
    String? profileImageUrl,
  }) async {
    final Map<String, dynamic> updateData = {
      'fullName': fullName.trim(),
      'mobile': mobile.trim(),
      'mobileNumber': mobile.trim(),
      'nic': nic.trim().toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (profileImageUrl != null) {
      updateData['profileImageUrl'] = profileImageUrl;
    }

    await _usersCollection.doc(uid).update(updateData);
  }

  /// Delete a user record from Firestore
  Future<void> deleteUser(String uid) async {
    await _usersCollection.doc(uid).delete();
  }
}
