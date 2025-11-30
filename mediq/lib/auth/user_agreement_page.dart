// user_agreement_page.dart

import 'package:flutter/material.dart';
import 'login_page.dart';
import '../main.dart'; // For AppColors

class UserAgreementPage extends StatefulWidget {
  const UserAgreementPage({super.key});

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
  bool _isAgreed = false;

  void _showDeclineMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 25),
                
                // Title
                Text(
                  'Agreement Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Message
                const Text(
                  'You must accept the User Agreement & Terms and Conditions to use this application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 25),
                
                // OK Button
                _buildGradientButton(
                  text: 'I Understand',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleAccept() {
    if (_isAgreed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _handleAcceptButton() {
    if (_isAgreed) {
      _handleAccept();
    }
    // If not agreed, do nothing (button will be disabled visually)
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: isEnabled
            ? const LinearGradient(
                colors: [
                  AppColors.buttonGradientStart,
                  AppColors.buttonGradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.buttonGradientEnd.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.grey.shade300,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.shade400,
          width: 2,
        ),
        color: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.darkText),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'User Agreement',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the row
                ],
              ),
              const SizedBox(height: 20),

              // Logo
              Image.asset(
                'assets/logo.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 5),

              // Title
              Text(
                'MediQ - User Agreement &',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Terms and Conditions',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Agreement Text Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.inputBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 14,
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(
                                text: 'By accessing or using ',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'MediQ - Antibiotic Usage Analysis System',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: ', you agree to use the platform responsibly and exclusively for authorized hospital purposes, including antibiotic management, inventory control, and data reporting. ',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'MediQ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: ' may securely collect operational records, system activity logs, and limited user information to enhance performance, strengthen security, and support hospital oversight. All data is handled with strict confidentiality and will only be accessed or shared when required by hospital administration or applicable laws.\n\n',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'Users must comply with hospital rules, maintain accurate entries, safeguard login credentials, and operate the system according to official guidelines. Unauthorized use, data manipulation, or attempts to breach system security may result in account suspension or administrative action. ',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'MediQ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: ' is provided "as is," and while reasonable measures are taken to ensure accuracy and availability, the platform is not liable for user errors, network issues, or delays caused by external factors. System updates, feature enhancements, and maintenance activities may occur without prior notice to improve functionality and reliability.\n\n',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'Your continued use of ',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              const TextSpan(
                                text: 'MediQ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: ' confirms your acceptance of these terms and your commitment to responsible and secure use of the platform.\n\n',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              WidgetSpan(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        color: AppColors.darkText,
                                        fontSize: 13,
                                        height: 1.5,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'MediQ – User Agreement & Terms\n\n',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.normal,
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'By using MediQ, you agree to use the system responsibly for authorized hospital tasks like antibiotic management and inventory control. MediQ may collect usage data and limited user information to improve performance and security. All data is kept confidential and only shared when required by the hospital or law. You must protect your account, enter data accurately, and follow hospital guidelines. Continued use means you accept these terms.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Agreement Checkbox
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: _isAgreed,
                        onChanged: (bool? value) {
                          setState(() {
                            _isAgreed = value ?? false;
                          });
                        },
                        activeColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I have read and accept the User Agreement & Terms and Conditions',
                        style: TextStyle(
                          color: AppColors.darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildOutlineButton(
                      text: 'Decline',
                      onPressed: _showDeclineMessage,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildGradientButton(
                      text: 'Accept',
                      onPressed: _handleAcceptButton,
                      isEnabled: _isAgreed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Footer
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