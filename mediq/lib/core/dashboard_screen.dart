// dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../admin/admin_drawer.dart';
import '../pharmacist/pharmacist_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _currentPage = 'Home';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      _currentUser = _auth.currentUser;
      
      if (_currentUser != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
            
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();
            _isLoading = false;
          });
        } else {
          // Handle case where user document doesn't exist
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // User not logged in, navigate to login
        _navigateToLogin();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/login', 
      (route) => false
    );
  }

  void _handleNavigation(String page) {
    setState(() {
      _currentPage = page;
    });
    // Here you can add logic to change the main content based on the page
    print('Navigating to: $page');
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _auth.signOut();
                _navigateToLogin();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent() {
    // This is where you'd build the main content based on _currentPage
    return Container(
      color: AppColors.lightBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard,
              size: 80,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to $_currentPage',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'User: ${_userData?['fullName'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkText.withOpacity(0.7),
              ),
            ),
            Text(
              'Role: ${_userData?['role'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkText.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Dashboard...',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'User data not found',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _navigateToLogin,
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final userRole = _userData!['role'];
    final userName = _userData!['fullName'] ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: userRole == 'Admin'
          ? AdminDrawer(
              userName: userName,
              userRole: userRole,
              onNavTap: _handleNavigation,
              onLogout: _handleLogout,
            )
          : PharmacistDrawer(
              userName: userName,
              userRole: userRole,
              onNavTap: _handleNavigation,
              onLogout: _handleLogout,
            ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: AppColors.darkText,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _currentPage,
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: AppColors.darkText,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _buildMainContent(),
    );
  }
}