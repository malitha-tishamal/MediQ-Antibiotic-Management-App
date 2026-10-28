import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  pharmacist;

  String get displayName => this == UserRole.admin ? 'Admin' : 'Pharmacist';

  static UserRole fromString(String? role) {
    if (role?.toLowerCase() == 'admin') return UserRole.admin;
    return UserRole.pharmacist;
  }
}

enum UserStatus {
  pending,
  approved,
  disabled;

  String get displayName {
    switch (this) {
      case UserStatus.approved:
        return 'Approved';
      case UserStatus.disabled:
        return 'Disabled';
      case UserStatus.pending:
        return 'Pending';
    }
  }

  static UserStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return UserStatus.approved;
      case 'disabled':
        return UserStatus.disabled;
      case 'pending':
      default:
        return UserStatus.pending;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String nic;
  final String mobile;
  final UserRole role;
  final UserStatus status;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.nic,
    required this.mobile,
    required this.role,
    this.status = UserStatus.pending,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isPharmacist => role == UserRole.pharmacist;
  bool get isApproved => status == UserStatus.approved;
  bool get isPending => status == UserStatus.pending;
  bool get isDisabled => status == UserStatus.disabled;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      nic: data['nic'] ?? '',
      mobile: data['mobile'] ?? data['mobileNumber'] ?? '',
      role: UserRole.fromString(data['role']),
      status: UserStatus.fromString(data['status']),
      profileImageUrl: data['profileImageUrl'],
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
      'email': email,
      'fullName': fullName,
      'nic': nic,
      'mobile': mobile,
      'mobileNumber': mobile,
      'role': role.displayName,
      'status': status.displayName,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? nic,
    String? mobile,
    UserRole? role,
    UserStatus? status,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      nic: nic ?? this.nic,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
