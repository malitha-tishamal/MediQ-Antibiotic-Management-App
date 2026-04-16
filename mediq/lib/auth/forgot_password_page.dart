// forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // AppColors

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _message = 'Password reset email sent. Please check your inbox.';
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }
      setState(() {
        _isLoading = false;
        _message = errorMessage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                // Back button row (minimal, like login page)
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.darkText,
                          size: 20,
                        ),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hero logo
                        Hero(
                          tag: 'app-logo',
                          child: Image.asset(
                            'assets/logo/logo.png',
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Reset Your Password',
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your email address and we will send you a link to reset your password.',
                          style: TextStyle(fontSize: 14, color: AppColors.darkText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Form with styled input field (matching LoginPage)
                        Form(
                          key: _formKey,
                          child: _buildEmailInput(),
                        ),
                        const SizedBox(height: 20),
                        // Message box
                        if (_message != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isSuccess ? Colors.green.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isSuccess ? Icons.check_circle_outline : Icons.error_outline_rounded,
                                  color: _isSuccess ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _message!,
                                    style: TextStyle(
                                      color: _isSuccess ? Colors.green : Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 30),
                        // Gradient button
                        _buildGradientButton(
                          text: _isLoading ? 'Sending...' : 'Send Reset Link',
                          onPressed: _isLoading ? null : _sendResetEmail,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Remember your password? ',
                              style: TextStyle(fontSize: 14, color: AppColors.darkText),
                            ),
                            GestureDetector(
                              onTap: _isLoading ? null : () => Navigator.pop(context),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Footer
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Developed By Malitha Tishamal',
                    style: TextStyle(color: AppColors.darkText, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Email input styled exactly like LoginPage's _buildInputField
  // ----------------------------------------------------------------------
  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Your Email',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'example@email.com',
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // Gradient button (matches LoginPage style)
  // ----------------------------------------------------------------------
  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final bool isDisabled = onPressed == null || isLoading;
    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isDisabled
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600])
              : const LinearGradient(
                  colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.buttonGradientEnd.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}