// user_agreement_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import '../main.dart'; // For AppColors

// Darker purple shades for text and accents (not for the button)
const Color _darkPurple = Color(0xFF6A1B9A);
const Color _deepPurple = Color(0xFF4A148C);

class UserAgreementPage extends StatefulWidget {
  const UserAgreementPage({super.key});

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrolledToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfScrolledToBottom() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isBottom = currentScroll >= maxScroll - 5.0;
    if (isBottom != _isScrolledToBottom) {
      setState(() {
        _isScrolledToBottom = isBottom;
      });
    }
  }

  void _scrollListener() {
    _checkIfScrolledToBottom();
  }

  Widget _buildTermsSection({
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.darkText.withOpacity(0.8),
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 16.0,
              bottom: 140.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact header: back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _deepPurple),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 4),

                // Logo and title row with Hero animation
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app-logo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/logo/logo.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.medical_services,
                            color: _darkPurple,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'MediQ – User\nAgreement & Terms and\nConditions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic, // Bold + Italic
                          color: _darkPurple,
                          height: 1.3,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Last updated
                const Text(
                  'Last Updated: April 2025',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 24),

                // Agreement sections
                _buildTermsSection(
                  title: '1. Approved Use and Data Collection',
                  content: 'By accessing or using MediQ - Antibiotic Usage Analysis System, you agree to use the platform responsibly and exclusively for authorized hospital purposes, including antibiotic management, inventory control, and data reporting. MediQ may securely collect operational records, system activity logs, and limited user information to enhance performance, strengthen security, and support hospital oversight.',
                ),
                _buildTermsSection(
                  title: '2. Confidentiality and Compliance',
                  content: 'All data is handled with strict confidentiality and will only be accessed or shared when required by hospital administration or applicable laws.',
                ),
                _buildTermsSection(
                  title: '3. User Responsibility and Misuse',
                  content: 'Users must comply with hospital rules, maintain accurate entries, safeguard login credentials, and operate the system according to official guidelines. Unauthorized use, data manipulation, or attempts to breach system security may result in account suspension or administrative action.',
                ),
                _buildTermsSection(
                  title: '4. Service Disclaimer',
                  content: 'MediQ is provided "as is," and while reasonable measures are taken to ensure accuracy and availability, the platform is not liable for user errors, network issues, or delays caused by external factors. System updates, feature enhancements, and maintenance activities may occur without prior notice to improve functionality and reliability.',
                ),
                const SizedBox(height: 24),

                // Final acceptance card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_darkPurple.withOpacity(0.08), _deepPurple.withOpacity(0.03)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _darkPurple.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'By continuing, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Fixed footer with button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Agree button with original gradient
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isScrolledToBottom
                          ? () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppColors.buttonGradientEnd.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 6,
                        shadowColor: AppColors.buttonGradientEnd.withOpacity(0.5),
                        padding: EdgeInsets.zero,
                      ).copyWith(
                        backgroundColor: _isScrolledToBottom
                            ? null
                            : WidgetStatePropertyAll(AppColors.buttonGradientEnd.withOpacity(0.3)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: _isScrolledToBottom
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.buttonGradientStart,
                                    AppColors.buttonGradientEnd,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _isScrolledToBottom ? null : AppColors.buttonGradientEnd.withOpacity(0.3),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            _isScrolledToBottom
                                ? "I Agree and Continue"
                                : "Scroll to Read Agreement",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Developed By Malitha Tishamal',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}