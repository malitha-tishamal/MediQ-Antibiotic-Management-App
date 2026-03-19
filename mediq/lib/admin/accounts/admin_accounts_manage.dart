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
  static const Color inputBorder = Color(0xFFE0E0E0);
  
  // Header gradient colors
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
    return const UserListScreen(role: 'Admin');
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

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Guest';
  String? _profileImageUrl;
  String? _currentUserId;
  bool _isUserLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ---------- Helper for consistent input decoration ----------
  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hintText,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: enabled ? AppColors.primaryPurple : Colors.grey.shade600,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(prefixIcon, color: AppColors.primaryPurple, size: 20),
              ),
            ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserDetails() async {
    setState(() => _isUserLoading = true);

    final user = _auth.currentUser;
    _currentUserId = user?.uid;

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

  // Header
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, left: 20, right: 20, bottom: 8),
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
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerTextDark, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Column(
              children: [
                Text(
                  _currentUserName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Logged in as: Administrator',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.headerTextDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage ${widget.role} Accounts',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // Search bar
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search by name, email, NIC, or mobile...',
          prefixIcon: Icon(Icons.search, color: AppColors.primaryPurple),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // Compact filter chips row
  Widget _buildModernFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: UserStatusFilter.values.map((filter) {
          final isSelected = _currentFilter == filter;
          Color color;
          switch (filter) {
            case UserStatusFilter.all:
              color = AppColors.primaryPurple;
              break;
            case UserStatusFilter.approved:
              color = AppColors.approvedColor;
              break;
            case UserStatusFilter.disabled:
              color = AppColors.disabledColor;
              break;
            case UserStatusFilter.pending:
              color = AppColors.pendingColor;
              break;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentFilter = filter;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getFilterName(filter),
                    style: TextStyle(
                      color: isSelected ? color : AppColors.darkText.withOpacity(0.5),
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
                _buildHeader(context),
                _buildSearchBar(),
                _buildModernFilterChips(),
                const SizedBox(height: 4),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _userCollection.where('role', isEqualTo: widget.role).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildModernLoadingState();
                      }
                      if (snapshot.hasError) {
                        return _buildModernErrorState(snapshot.error.toString());
                      }
                      final documents = snapshot.data?.docs ?? [];

                      // Apply filters: status + search
                      final filteredDocs = documents.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        
                        if (_currentFilter != UserStatusFilter.all) {
                          final status = data['status'] ?? '';
                          if (status != _getFilterStatusValue(_currentFilter)) return false;
                        }
                        
                        if (_searchQuery.isNotEmpty) {
                          final fullName = (data['fullName'] ?? '').toLowerCase();
                          final email = (data['email'] ?? '').toLowerCase();
                          final nic = (data['nic'] ?? '').toLowerCase();
                          final mobile = (data['mobile'] ?? '').toLowerCase();
                          if (!fullName.contains(_searchQuery) &&
                              !email.contains(_searchQuery) &&
                              !nic.contains(_searchQuery) &&
                              !mobile.contains(_searchQuery)) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildModernEmptyState();
                      }
                      return ListView.builder(
                        key: const PageStorageKey('admin_user_list'),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final userId = doc.id;
                          return _buildModernUserCard(userId, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Footer
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 255, 255, 255),
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

  // ----- Updated User Card with larger avatar and horizontal action buttons -----
  Widget _buildModernUserCard(String userId, Map<String, dynamic> data) {
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

    final bool isCurrentUser = userId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9F7FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: statusColor,
                  width: 6,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Larger profile avatar (60x60)
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
                            color: statusColor.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
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
                          ? const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ),
                              // Edit button with modern container
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.primaryPurple, size: 18),
                                  onPressed: () => _showEditDialog(userId, fullName, mobile, nic),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Status chip with border
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 12,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(Icons.email, email, fontSize: 12),
                          const SizedBox(height: 4),
                          _buildInfoRow(Icons.badge, 'NIC: $nic', fontSize: 12),
                          const SizedBox(height: 4),
                          _buildInfoRow(Icons.phone, 'Mobile: $mobile', fontSize: 12),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 10,
                                color: AppColors.darkText.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 10,
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
                const SizedBox(height: 12),
                // Horizontal Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildModernActionButton(
                        'Approve',
                        isCurrentUser ? Colors.grey : AppColors.successGreen,
                        Icons.check_circle,
                        isCurrentUser || status == 'Approved',
                        isCurrentUser ? null : () => _updateStatus(userId, 'Approved'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModernActionButton(
                        'Disable',
                        isCurrentUser ? Colors.grey : AppColors.disabledColor,
                        Icons.lock,
                        isCurrentUser || status == 'Disabled',
                        isCurrentUser ? null : () => _updateStatus(userId, 'Disabled'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModernActionButton(
                        'Delete',
                        isCurrentUser ? Colors.grey : AppColors.warningOrange,
                        Icons.delete_outline,
                        isCurrentUser,
                        isCurrentUser ? null : () => _confirmDelete(userId, fullName),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {double fontSize = 13}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: AppColors.darkText.withOpacity(0.5),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.darkText.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  // Horizontal action button
  Widget _buildModernActionButton(
    String label,
    Color color,
    IconData icon,
    bool isDisabled,
    VoidCallback? onTap,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled ? Colors.grey.withOpacity(0.3) : color.withOpacity(0.5),
              width: isDisabled ? 1 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDisabled ? Colors.grey : color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern loading state
  Widget _buildModernLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryPurple),
    );
  }

  // Modern error state
  Widget _buildModernErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.disabledColor),
            const SizedBox(height: 16),
            Text('Error loading data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Modern empty state
  Widget _buildModernEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No ${widget.role} accounts found', style: TextStyle(color: Colors.grey, fontSize: 16)),
          if (_searchQuery.isNotEmpty || _currentFilter != UserStatusFilter.all)
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _currentFilter = UserStatusFilter.all;
                });
              },
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(String userId, String currentName, String currentMobile, String currentNic) {
    final nameController = TextEditingController(text: currentName);
    final mobileController = TextEditingController(text: currentMobile);
    final nicController = TextEditingController(text: currentNic);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.primaryPurple),
            SizedBox(width: 12),
            Text('Edit Admin Details'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration(
                    label: 'Full Name',
                    prefixIcon: Icons.person,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileController,
                  decoration: _inputDecoration(
                    label: 'Mobile Number',
                    prefixIcon: Icons.phone,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Mobile is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nicController,
                  decoration: _inputDecoration(
                    label: 'NIC',
                    prefixIcon: Icons.badge,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'NIC is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.darkText.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                await _updateUserDetails(
                  userId,
                  nameController.text.trim(),
                  mobileController.text.trim(),
                  nicController.text.trim(),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserDetails(String userId, String newName, String newMobile, String newNic) async {
    try {
      await _userCollection.doc(userId).update({
        'fullName': newName,
        'mobile': newMobile,
        'nic': newNic,
      });
      _showSnackBar('Details updated successfully', true);
    } catch (e) {
      _showSnackBar('Failed to update details: $e', false);
    }
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
            SizedBox(width: 12),
            Text('Delete Account'),
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