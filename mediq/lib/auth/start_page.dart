// start_page.dart

import 'package:flutter/material.dart';
import '../main.dart';
import 'login_page.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.height < 700;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: <Widget>[
              // Top spacer - flexible
              const Spacer(flex: 2),

              // Logo section
              _buildLogoSection(isSmallScreen),

              // Title section
              _buildTitleSection(),

              // Middle spacer - takes most space
              const Spacer(flex: 3),

              // Button section
              _buildStartButton(context),

              // Footer section with bottom spacing
              _buildFooterSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isSmallScreen) {
    return Hero(
      tag: 'app-logo',
      child: Image.asset(
        'assets/logo.png', // **CHANGE THIS TO YOUR LOGO PATH**
        height: isSmallScreen ? 200 : 250,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTitleSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20.0),
      child: Text(
        'Antibiotics\nManagement\nSystem',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.darkText,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.2,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
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
              color: AppColors.buttonGradientEnd.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Add slight scale animation on tap
              _navigateToLogin(context);
            },
            onTapDown: (_) {},
            borderRadius: BorderRadius.circular(15),
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.1),
            child: const Center(
              child: Text(
                "Let's Start...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return const Padding(
      padding: EdgeInsets.only(top: 40.0, bottom: 20.0),
      child: Text(
        'Developed By Malitha Tishamal',
        style: TextStyle(
          color: AppColors.darkText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}