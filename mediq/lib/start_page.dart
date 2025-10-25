// start_page.dart

import 'package:flutter/material.dart';
import 'main.dart'; // Import to use AppColors
import 'login_page.dart'; // Create this file for navigation

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We wrap the whole content in a Center and Padding
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute space
            children: <Widget>[
              const Spacer(flex: 2), // Top spacing

              Image.asset(
                'assets/logo.png', // **CHANGE THIS TO YOUR LOGO PATH**
                height: 250,
              ),

              const SizedBox(height: 20),

              // Title Text
              const Text(
                'Antibiotics\nManagement\nSystem',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const Spacer(flex: 3), // Middle spacing

              // ------------------- "Let's Start..." Button -------------------
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  // Apply the gradient seen in the image
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.buttonGradientStart,
                      AppColors.buttonGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.buttonGradientEnd.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent, // Important for the gradient to show
                  child: InkWell(
                    onTap: () {
                      // Navigate to the Login Page
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: const Center(
                      child: Text(
                        "Let's Start...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 1), // Spacing before footer

              // ------------------- Footer -------------------
              const Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'Developed By Malitha Tishamal',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}