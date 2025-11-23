import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- AppColors Class ---
class AppColors {
 static const Color primaryPurple = Color(0xFF9F7AEA);
 static const Color lightBackground = Color(0xFFF3F0FF);
 static const Color darkText = Color(0xFF333333);
 static const Color totalCountColor = Color(0xFF1E88E5);
 static const Color approvedColor = Color(0xFF4CAF50);
 static const Color disabledColor = Color(0xFFE53935);
 static const Color pendingColor = Color(0xFFFF9800);
}

// --- Account Management Details Screen ---
class AccountManageDetails extends StatelessWidget {
 // FIX: This field is initialized using a runtime method call (FirebaseFirestore.instance).
 // Therefore, it cannot be used in a const constructor.
 final CollectionReference _userCollection =
   FirebaseFirestore.instance.collection('users');

 // FIX: Removed 'const' keyword from the constructor definition.
 AccountManageDetails({super.key});

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   backgroundColor: AppColors.lightBackground,
   appBar: AppBar(
    title: const Text('Manage Accounts', style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
    backgroundColor: AppColors.lightBackground,
    elevation: 0,
    iconTheme: const IconThemeData(color: AppColors.darkText),
   ),
   
   // Main scrollable body content
   body: SafeArea(
    child: SingleChildScrollView(
     padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
     child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       // Admin Accounts Header
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
       // Admin Account Card (Live Count)
       _buildAccountCard(
        role: 'Admin',
        title: 'Manage Admin Accounts',
        icon: Icons.admin_panel_settings,
       ),
       
       const SizedBox(height: 24),
       
       // Pharmacist Accounts Header
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
       // Pharmacist Account Card (Live Count)
       _buildAccountCard(
        role: 'Pharmacist',
        title: 'Manage Pharmacist Accounts',
        icon: Icons.local_pharmacy,
       ),
      ],
     ),
    ),
   ),
   
   // Bottom navigation for the developer credit
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

 // --- Account Card Widget (Real-time data fetcher) ---
 Widget _buildAccountCard({
  required String role,
  required String title,
  required IconData icon,
 }) {
  return StreamBuilder<QuerySnapshot>(
   stream: _userCollection.snapshots(),
   builder: (context, snapshot) {
    int total = 0;
    int approved = 0;
    int disabled = 0;
    int pending = 0;
        
    // 1. Data Processing Logic
    if (snapshot.hasData && snapshot.data != null) {
     // Filter and categorize based on role and status
     for (var doc in snapshot.data!.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userRole = data['role'];
      final userStatus = data['status']; // e.g., 'Approved', 'Disabled', 'Pending'

      if (userRole == role) {
       total++;
       
       if (userStatus == 'Approved') {
        approved++;
       } else if (userStatus == 'Disabled') {
        disabled++;
       } else if (userStatus == 'Pending') {
        pending++;
       }
      }
     }
    }

    // 2. UI Rendering based on connection state
    if (snapshot.connectionState == ConnectionState.waiting) {
     return _buildLoadingCard(title);
    }

    if (snapshot.hasError) {
     return _buildErrorCard(title, snapshot.error.toString());
    }

    // 3. Display Counts
    return Container(
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
       // Icon/Image Placeholder
       Icon(icon, size: 60, color: AppColors.primaryPurple.withOpacity(0.8)),
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
    );
   },
  );
 }

 // --- Helper for individual stat row ---
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

 // --- Helper for loading state ---
 Widget _buildLoadingCard(String title) {
  return Container(
   padding: const EdgeInsets.all(16),
   height: 160,
   decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
   ),
   child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
     Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
     const SizedBox(height: 12),
     const LinearProgressIndicator(color: AppColors.primaryPurple),
     const SizedBox(height: 8),
     const Text('Loading live counts...', style: TextStyle(fontSize: 12, color: Colors.grey)),
    ],
   ),
  );
 }

 // --- Helper for error state ---
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
     Text('Error fetching data. Check Firebase rules!',
      style: TextStyle(fontSize: 12, color: AppColors.disabledColor)),
     Text(error, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ],
   ),
  );
 }
}