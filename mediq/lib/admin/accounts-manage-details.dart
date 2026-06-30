import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_drawer.dart';
import '../auth/login_page.dart';
import 'accounts/admin_accounts_manage.dart';
import 'accounts/pharmacist_accounts_manage.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color totalCountColor = Color(0xFF1E88E5);
  static const Color approvedColor = Color(0xFF4CAF50);
  static const Color disabledColor = Color(0xFFE53935);
  static const Color pendingColor = Color(0xFFFF9800);
  static const Color iconColor = Color(0xFF5A43A7);

  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
            _profileImageUrl = data['profileImageUrl'];
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

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Menu button (left)
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              // User info (centered)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Administrator',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Profile picture (right)
              _buildDashboardProfileAvatar(),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Account Management Dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) {
          if (mounted) setState(() => _profileImageUrl = null);
        },
      );
    } else {
      return CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
        child: const Icon(Icons.person, color: AppColors.primaryPurple, size: 48),
      );
    }
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
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: (title) => _handleNavTap(title, context),
        onLogout: () => _handleLogout(context),
      ),
      // ✅ No appBar – custom header handles everything without layout issues
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildDashboardHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildSectionTitle('Manage Admin Accounts', Icons.admin_panel_settings),
                        const SizedBox(height: 10),
                        _buildAccountCard(
                          role: 'Admin',
                          title: 'Manage Admin Accounts',
                          imagePath: 'assets/accounts/admin-default.jpg',
                          borderColor: Colors.deepPurpleAccent,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Manage Pharmacist Accounts', Icons.medical_services),
                        const SizedBox(height: 10),
                        _buildAccountCard(
                          role: 'Pharmacist',
                          title: 'Manage Pharmacist Accounts',
                          imagePath: 'assets/accounts/pharmizist-default.jpg',
                          borderColor: CupertinoColors.systemPurple,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 255, 254, 254),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required String role,
    required String title,
    required String imagePath,
    required Color borderColor,
  }) {
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

            if (userStatus == 'Approved') {
              approved++;
            } else if (userStatus == 'Disabled') {
              disabled++;
            } else if (userStatus == 'Pending') {
              pending++;
            }
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildModernLoadingCard(title);
        }

        if (snapshot.hasError) {
          return _buildModernErrorCard(title, snapshot.error.toString());
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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF9F7FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: borderColor,
                        width: 8,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: borderColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
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
                                  color: borderColor.withOpacity(0.8),
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
              ),
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

  Widget _buildModernLoadingCard(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9F7FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

  Widget _buildModernErrorCard(String title, String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9F7FF)],
        ),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
          const SizedBox(height: 8),
          const Text(
            'Error fetching data. Check Firebase rules!',
            style: TextStyle(fontSize: 12, color: AppColors.disabledColor),
          ),
          Text(error, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}