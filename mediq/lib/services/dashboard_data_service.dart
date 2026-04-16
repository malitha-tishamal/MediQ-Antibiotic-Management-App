import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/firestore.dart'; // if using Firestore

class DashboardDataService {
  static final DashboardDataService instance = DashboardDataService._internal();
  factory DashboardDataService() => instance;
  DashboardDataService._internal();

  bool _isPreloaded = false;
  Map<String, dynamic>? _cachedData;

  Future<void> preloadAllData() async {
    if (_isPreloaded) return;

    // Fetch all required data concurrently
    final results = await Future.wait([
      _fetchUserRole(),
      _fetchCounts(),
      _fetchRecentActivities(),
      // Add more futures as needed
    ]);

    _cachedData = {
      'role': results[0],
      'counts': results[1],
      'recent': results[2],
    };
    _isPreloaded = true;
  }

  Future<String> _fetchUserRole() async {
    // Example: get role from Firestore using current user UID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'none';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.get('role') ?? 'pharmacist';
  }

  Future<Map<String, int>> _fetchCounts() async {
    // Example: fetch dashboard counters
    // Replace with actual API / Firestore queries
    return {
      'admins': 5,
      'pharmacists': 12,
      'totalFound': 2450,
      'totalWards': 8,
      'stockTypes': 15,
      'releases': 103,
      'returns': 47,
    };
  }

  Future<List<dynamic>> _fetchRecentActivities() async {
    // Example: fetch recent transactions or logs
    return []; // Replace with real data
  }

  // Getters for the dashboard to use preloaded data instantly
  String getUserRole() => _cachedData?['role'] ?? 'unknown';
  Map<String, int> getCounts() => _cachedData?['counts'] ?? {};
  List<dynamic> getRecentActivities() => _cachedData?['recent'] ?? [];
}