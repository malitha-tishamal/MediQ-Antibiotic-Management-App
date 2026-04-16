import 'dart:async';
import 'package:flutter/material.dart';
import '../core/dashboard_wrapper.dart';
import '../main.dart';

class SimplePreloadScreen extends StatefulWidget {
  const SimplePreloadScreen({super.key});

  @override
  State<SimplePreloadScreen> createState() => _SimplePreloadScreenState();
}

class _SimplePreloadScreenState extends State<SimplePreloadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Animation controller for bubbles
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    // Wait exactly 1 second, then navigate to dashboard
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/logo/logo.png',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 40),
            // Loading Bubbles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final double value = _animationController.value;
                    // Each bubble scales with a phase shift
                    double scale = 1.0;
                    if (index == 0) scale = 0.6 + (value * 0.4);
                    if (index == 1) scale = 1.0;
                    if (index == 2) scale = 0.8 - (value * 0.2);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text(
              'Just a moment...',
              style: TextStyle(color: AppColors.darkestText),
            ),
          ],
        ),
      ),
    );
  }
}