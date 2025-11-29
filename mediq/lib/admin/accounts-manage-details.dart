
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_drawer.dart';
import '../auth/login_page.dart';
import 'admin_accounts_manage.dart';
import 'pharmacist_accounts_manage.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color totalCountColor = Color(0xFF1E88E5);
  static const Color approvedColor = Color(0xFF4CAF50);
  static const Color disabledColor = Color(0xFFE53935);
  static const Color pendingColor = Color(0xFFFF9800);
  static const Color iconColor = Color(0xFF5A43A7);
}

class AccountManageDetails extends StatefulWidget {
  const AccountManageDetails({super.key});

  @override
  State<AccountManageDetails> createState() => _AccountManageDetailsState();
}

class _AccountManageDetailsState extends State<AccountManageDetails> {
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Guest';
  String? _profileImageUrl;
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
  }

  Future<void> _fetchCurrentUserDetails() async {
    setState(() => _isUserLoading = true);

    final user = _auth.currentUser;

    if (user != null) {
      try {
        final doc = await _userCollection.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName =
                data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _currentUserRole = data['role'] ?? 'Unassigned';
            _profileImageUrl = data['profileImageUrl']; // Firestore image
          });
        } else {
          setState(() {
            _currentUserName = user.email?.split('@').first ?? 'Authenticated User';
            _currentUserRole = 'Profile Missing';
          });
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load user data: $e')),
          );
        }
      }
    }
    setState(() => _isUserLoading = false);
  }

  void _handleNavTap(String title, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigation to $title is currently a placeholder.')),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildHeaderCard(String name, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6D6F7), Color(0xFFE9D7FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.6),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? Image.network(
                      _profileImageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 48,
                          color: AppColors.primaryPurple,
                        );
                      },
                    )
                  : const Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.primaryPurple,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isUserLoading ? 'Fetching Details...' : 'Welcome Back, $name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.darkText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 18.0, top: 8.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Builder(
            builder: (BuildContext innerContext) {
              return IconButton(
                icon: const Icon(Icons.menu, color: AppColors.darkText, size: 30),
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserLoading) {
      return const Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        //profileImageBase64: null,
        onNavTap: (title) => _handleNavTap(title, context),
        onLogout: () => _handleLogout(context),
      ),
      appBar: const PreferredSize(preferredSize: Size.fromHeight(0), child: SizedBox.shrink()),
      body: SafeArea(
        child: Column(
          children: [
            _buildMenuButton(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(_currentUserName, _currentUserRole),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 0.0, bottom: 20.0, top: 10.0),
                      child: Text(
                        'Manage Accounts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 6.0, bottom: 10),
                      child: Text(
                        'Manage Admin Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    _buildAccountCard(
                      role: 'Admin',
                      title: 'Manage Admin Accounts',
                      imagePath: 'assets/admin-default.jpg',
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 6.0, bottom: 10),
                      child: Text(
                        'Manage Pharmacist Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    _buildAccountCard(
                      role: 'Pharmacist',
                      title: 'Manage Pharmacist Accounts',
                      imagePath: 'assets/pharmizist-default.jpg',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Text(
          'Developed By Malitha Tishamal',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.darkText.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required String role,
    required String title,
    required String imagePath,
  }) {
    const double circularRadius = 40.0;

    return StreamBuilder<QuerySnapshot>(
      stream: _userCollection.where('role', isEqualTo: role).snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        int approved = 0;
        int disabled = 0;
        int pending = 0;

        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          total = docs.length;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final userStatus = data['status'] ?? 'Pending';

            if (userStatus == 'Approved') approved++;
            else if (userStatus == 'Disabled') disabled++;
            else if (userStatus == 'Pending') pending++;
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(title);
        }

        if (snapshot.hasError) {
          return _buildErrorCard(title, snapshot.error.toString());
        }

        return InkWell(
          onTap: () {
            if (role == 'Admin') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminAccountsManagePage()),
              );
            } else if (role == 'Pharmacist') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PharmacistAccountsManagePage()),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(circularRadius),
                    border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(circularRadius),
                    child: Image.asset(
                      imagePath,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.person_search,
                            size: 40,
                            color: AppColors.primaryPurple.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow('Total', total.toString(), AppColors.totalCountColor),
                      _buildStatRow('Approved', approved.toString(), AppColors.approvedColor),
                      _buildStatRow('Disabled', disabled.toString(), AppColors.disabledColor),
                      _buildStatRow('Pending', pending.toString(), AppColors.pendingColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkText.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: AppColors.primaryPurple),
          const SizedBox(height: 8),
          const Text(
            'Loading live counts...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String title, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
          const SizedBox(height: 8),
          Text(
            'Error fetching data. Check Firebase rules!',
            style: TextStyle(fontSize: 12, color: AppColors.disabledColor),
          ),
          Text(error, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

