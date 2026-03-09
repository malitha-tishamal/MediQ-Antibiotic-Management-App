// book_numbers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_drawer.dart'; // AdminDrawer import
import '../auth/login_page.dart'; // LoginPage import

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color darkText = Color(0xFF2D3748);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color disabledColor = Color(0xFFF56565);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF2D3748);
}

class BookNumbersScreen extends StatefulWidget {
  const BookNumbersScreen({super.key});

  @override
  State<BookNumbersScreen> createState() => _BookNumbersScreenState();
}

class _BookNumbersScreenState extends State<BookNumbersScreen> {
  final CollectionReference _bookNumbersCollection =
      FirebaseFirestore.instance.collection('book_numbers');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details for header
  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;

  // Controller for add book number field
  final TextEditingController _addController = TextEditingController();

  // Scaffold key for drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName =
                data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _currentUserRole = data['role'] ?? 'Administrator';
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  // Drawer navigation handler
  void _onNavTap(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title tapped')),
    );
  }

  // Logout function
  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  // Header - with menu button
  Widget _buildHeader(BuildContext context) {
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
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged in as: Administrator',
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
          const Text(
            'Manage Book Numbers',
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

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Add new book number
  Future<void> _addBookNumber() async {
    if (_addController.text.trim().isEmpty) {
      _showSnackBar('Please enter a book number', false);
      return;
    }
    try {
      await _bookNumbersCollection.add({
        'bookNumber': _addController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      _addController.clear();
      _showSnackBar('Book number added successfully', true);
    } catch (e) {
      _showSnackBar('Failed to add: $e', false);
    }
  }

  // Toggle status between active and completed
  Future<void> _toggleStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'active' ? 'completed' : 'active';
    try {
      await _bookNumbersCollection.doc(docId).update({'status': newStatus});
      _showSnackBar('Status updated to $newStatus', true);
    } catch (e) {
      _showSnackBar('Update failed: $e', false);
    }
  }

  // Edit book number (show dialog)
  void _editBookNumber(BuildContext context, String docId, String currentNumber) {
    final TextEditingController editController = TextEditingController(text: currentNumber);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.primaryPurple),
            SizedBox(width: 10),
            Text('Edit Book Number'),
          ],
        ),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: 'Book Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            prefixIcon: const Icon(Icons.menu_book, color: AppColors.primaryPurple),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.darkText.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isEmpty) {
                _showSnackBar('Book number cannot be empty', false);
                return;
              }
              try {
                await _bookNumbersCollection.doc(docId).update({
                  'bookNumber': editController.text.trim(),
                });
                Navigator.pop(ctx);
                _showSnackBar('Updated successfully', true);
              } catch (e) {
                Navigator.pop(ctx);
                _showSnackBar('Update failed: $e', false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Delete with confirmation
  Future<void> _deleteBookNumber(String docId, String bookNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
            SizedBox(width: 12),
            Text('Delete Book Number'),
          ],
        ),
        content: Text('Are you sure you want to delete "$bookNumber"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.darkText.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _bookNumbersCollection.doc(docId).delete();
        _showSnackBar('Deleted successfully', true);
      } catch (e) {
        _showSnackBar('Delete failed: $e', false);
      }
    }
  }

  /// නවීන book number card එක (overflow fixed)
  Widget _buildBookCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bookNumber = data['bookNumber'] ?? 'N/A';
    final status = data['status'] ?? 'active';
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final formattedDate = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
        : '-';

    final bool isActive = status == 'active';
    final Color statusColor = isActive ? AppColors.successGreen : Colors.grey;
    final String statusText = isActive ? 'Active' : 'Completed';
    final IconData statusIcon = isActive ? Icons.check_circle : Icons.block;

    return Container(
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
            color: statusColor.withOpacity(0.2),
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
                  color: statusColor,
                  width: 8,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16), // slightly reduced to avoid overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with ID, Book Number, Date (overflow fixed)
                Row(
                  children: [
                    // ID section
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'ID: ${doc.id.substring(0, 4)}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Book Number section
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book, size: 16, color: AppColors.primaryPurple),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bookNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date section
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Row with Status and Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status chip with border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      children: [
                        // Toggle button
                        Material(
                          borderRadius: BorderRadius.circular(14),
                          color: statusColor.withOpacity(0.1),
                          child: InkWell(
                            onTap: () => _toggleStatus(doc.id, status),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.lock : Icons.lock_open,
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Disable' : 'Activate',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Edit button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                            onPressed: () => _editBookNumber(context, doc.id, bookNumber),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Delete button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _deleteBookNumber(doc.id, bookNumber),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: _onNavTap,
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                // Add book number section (updated border)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addController,
                          decoration: InputDecoration(
                            hintText: 'Enter Book Number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.menu_book, color: AppColors.primaryPurple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addBookNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                // List of book numbers
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _bookNumbersCollection.orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text('No book numbers found.'),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          return _buildBookCard(docs[index]);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Footer
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}