import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../core/app_config.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign up user and create user profile in Firestore
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String nic,
    required String mobile,
    required UserRole role,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final defaultProfileImage = role == UserRole.admin
        ? AppConfig.defaultAdminProfileUrl
        : AppConfig.defaultPharmacistProfileUrl;

    final userData = UserModel(
      uid: userCredential.user!.uid,
      email: email.trim(),
      fullName: fullName.trim(),
      nic: nic.trim().toUpperCase(),
      mobile: mobile.trim(),
      role: role,
      status: UserStatus.pending,
      profileImageUrl: defaultProfileImage,
    ).toMap();

    userData['createdAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .set(userData);

    return userCredential;
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch current user's profile
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromFirestore(doc);
  }

  /// Stream of current user's profile
  Stream<UserModel?> streamCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
}
