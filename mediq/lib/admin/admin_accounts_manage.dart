import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color approvedColor = Color(0xFF4CAF50);
  static const Color disabledColor = Color(0xFFE53935);
  static const Color pendingColor = Color(0xFFFF9800);
  static const Color iconColor = Color(0xFF5A43A7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF00C853);
  static const Color warningOrange = Color(0xFFFF6D00);
  
  // Header gradient colors matching Factory Owner Dashboard
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

// Enum for filtering users
enum UserStatusFilter { all, approved, disabled, pending }

class AdminAccountsManagePage extends StatelessWidget {
  const AdminAccountsManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return UserListScreen(role: 'Admin');
  }
}

class UserListScreen extends StatefulWidget {
  final String role;
  const UserListScreen({super.key, required this.role});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserStatusFilter _currentFilter = UserStatusFilter.all;

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

  String? _getFilterStatusValue(UserStatusFilter filter) {
    switch (filter) {
      case UserStatusFilter.approved:
        return 'Approved';
      case UserStatusFilter.disabled:
        return 'Disabled';
      case UserStatusFilter.pending:
        return 'Pending';
      case UserStatusFilter.all:
      default:
        return null;
    }
  }

  String _getFilterName(UserStatusFilter filter) {
    switch (filter) {
      case UserStatusFilter.all:
        return 'All';
      case UserStatusFilter.approved:
        return 'Approved';
      case UserStatusFilter.disabled:
        return 'Disabled';
      case UserStatusFilter.pending:
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  // 🌟 NEW HEADER - Factory Owner Dashboard Style
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Profile Picture
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryPurple, Color(0xFFB08FEB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 15),
              
              // User Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  // Role
                  Text(
                    'Logged in as: $_currentUserName \n($_currentUserRole)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          
          // Page Title
          Text(
            'Manage ${widget.role} Accounts',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 🌟 NEW HEADER
                _buildDashboardHeader(context),
                
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Modern Filter Chips
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: UserStatusFilter.values.map((filter) {
                            final isSelected = _currentFilter == filter;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentFilter = filter;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryPurple : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getFilterName(filter),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.darkText.withOpacity(0.6),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      // User List
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _getFilterStatusValue(_currentFilter) == null
                              ? _userCollection.where('role', isEqualTo: widget.role).snapshots()
                              : _userCollection
                                  .where('role', isEqualTo: widget.role)
                                  .where('status', isEqualTo: _getFilterStatusValue(_currentFilter))
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primaryPurple,
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading users...',
                                      style: TextStyle(
                                        color: AppColors.darkText.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: AppColors.disabledColor,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading data',
                                      style: TextStyle(
                                        color: AppColors.darkText.withOpacity(0.7),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final documents = snapshot.data?.docs ?? [];
                            if (documents.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      color: AppColors.darkText.withOpacity(0.3),
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No ${widget.role} accounts found',
                                      style: TextStyle(
                                        color: AppColors.darkText.withOpacity(0.5),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                final data = documents[index].data() as Map<String, dynamic>;
                                final userId = documents[index].id;
                                return _buildUserCard(userId, data);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Fixed Footer Text
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? 'Malitha Tishamal';
    final email = data['email'] ?? 'malithatishamal@gmail.com';
    final nic = data['nic'] ?? '200302202615';
    final mobile = data['mobile'] ?? '0785530992';
    final status = data['status'] ?? 'Pending';
    final profileImageUrl = data['profileImageUrl'];
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final formattedDate = DateFormat('MMM dd, yyyy – HH:mm').format(createdAt);

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = AppColors.successGreen;
        statusText = 'Approved';
        statusIcon = Icons.verified;
        break;
      case 'Disabled':
        statusColor = AppColors.disabledColor;
        statusText = 'Disabled';
        statusIcon = Icons.block;
        break;
      default:
        statusColor = AppColors.warningOrange;
        statusText = 'Pending';
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Profile Avatar with Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: profileImageUrl == null 
                        ? LinearGradient(
                            colors: [
                              AppColors.primaryPurple.withOpacity(0.8),
                              AppColors.primaryPurple,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: profileImageUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(profileImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profileImageUrl == null 
                      ? Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.email, email),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.badge, 'NIC: $nic'),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.phone, 'Mobile: $mobile'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: AppColors.darkText.withOpacity(0.4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.darkText.withOpacity(0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Modern Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernActionButton(
                      'Approve',
                      AppColors.successGreen,
                      Icons.check_circle,
                      status == 'Approved',
                      () => _updateStatus(userId, 'Approved'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernActionButton(
                      'Disable',
                      AppColors.disabledColor,
                      Icons.lock,
                      status == 'Disabled',
                      () => _updateStatus(userId, 'Disabled'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernActionButton(
                      'Delete',
                      AppColors.warningOrange,
                      Icons.delete_outline,
                      false,
                      () => _confirmDelete(userId, fullName),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.darkText.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.darkText.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionButton(
    String label,
    Color color,
    IconData icon,
    bool isCurrentStatus,
    VoidCallback onTap,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isCurrentStatus ? color.withOpacity(0.2) : color.withOpacity(0.1),
      child: InkWell(
        onTap: isCurrentStatus ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentStatus ? color.withOpacity(0.3) : color.withOpacity(0.5),
              width: isCurrentStatus ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isCurrentStatus ? color.withOpacity(0.6) : color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isCurrentStatus ? color.withOpacity(0.6) : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String userId, String status) async {
    try {
      await _userCollection.doc(userId).update({'status': status});
      _showSnackBar('Status updated to $status', true);
    } catch (e) {
      _showSnackBar('Failed to update status: $e', false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _userCollection.doc(userId).delete();
      _showSnackBar('User deleted successfully', true);
    } catch (e) {
      _showSnackBar('Failed to delete user: $e', false);
    }
  }

  void _confirmDelete(String userId, String fullName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: Text('Are you sure you want to delete $fullName\'s account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.disabledColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteUser(userId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}