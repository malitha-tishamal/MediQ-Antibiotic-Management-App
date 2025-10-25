// firebase_load_check_screen.dart

import 'package:flutter/material.dart';
import 'main.dart'; // Import to access AppColors

class FirebaseLoadCheckScreen extends StatelessWidget {
  const FirebaseLoadCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Use a distinct background color for the loading state
      backgroundColor: AppColors.primaryPurple, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Standard Flutter loading indicator
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            
            // Simple loading message
            Text(
              "Checking user status...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}