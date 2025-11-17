import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// FIX: Hiding AuthWrapper from main.dart to resolve the ambiguous import error.
// We only need AppColors from main.dart here.
import '../main.dart' hide AuthWrapper; 
import 'auth_wrapper.dart'; // The standard starting point after onboarding
import 'start_page.dart'; // The onboarding page


class StartUpCheckScreen extends StatefulWidget {
  const StartUpCheckScreen({super.key});

  @override
  State<StartUpCheckScreen> createState() => _StartUpCheckScreenState();
}

class _StartUpCheckScreenState extends State<StartUpCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Start checking preferences as soon as the widget is created
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    // 1. Get the SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // 2. Check the flag. Default to false if the key doesn't exist (first run).
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 3. Schedule the navigation after the current frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        if (hasSeenOnboarding) {
          // If seen, go straight to the authentication check
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
          );
        } else {
          // If not seen, go to the StartPage (Onboarding)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const StartPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal splash screen while preferences are loading.
    // This is visible for a split second before redirection happens.
    return const Scaffold(
      backgroundColor: AppColors.primaryPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_outlined, size: 80, color: Colors.white),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
