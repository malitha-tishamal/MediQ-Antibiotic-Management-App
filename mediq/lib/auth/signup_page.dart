import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'login_page.dart';

enum UserRole { Admin, Pharmacist }

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _nic = '';
  String _fullName = '';
  String _mobileNumber = '';
  UserRole _selectedRole = UserRole.Pharmacist;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordMatch);
    _confirmPasswordController.addListener(_validatePasswordMatch);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String?> _getDefaultProfilePicture() async {
    try {
      String assetPath = _selectedRole == UserRole.Admin
          ? 'assets/admin-default.jpg'
          : 'assets/pharmacist-default.jpg';
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      return '';
    }
  }

  void _validatePasswordMatch() {
    if (_confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _handleSignUp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? defaultProfileImage = await _getDefaultProfilePicture();
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _email.trim(),
        password: _password,
      );

      final userData = {
        'email': _email.trim(),
        'role': _selectedRole.name,
        'fullName': _fullName.trim(),
        'nic': _nic.trim().toUpperCase(),
        'mobileNumber': _mobileNumber.trim(),
        'status': 'Pending',
        'profileImageUrl': defaultProfileImage ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
      if (mounted) await _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleGenericError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'weak-password':
        message = 'The password provided is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        message = 'An account already exists with this email address.';
      case 'invalid-email':
        message = 'The email address is not valid.';
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled.';
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
      default:
        message = 'Registration failed: ${e.message}';
    }
    if (mounted) setState(() => _errorMessage = message);
  }

  void _handleGenericError(dynamic e) {
    if (mounted) setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    debugPrint('SignUp Error: $e');
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _selectedRole == UserRole.Admin ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedRole == UserRole.Admin ? Icons.admin_panel_settings : Icons.medical_services,
                    color: _selectedRole == UserRole.Admin ? Colors.purple : Colors.blue,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  '${_selectedRole.name} Account Created\nSuccessfully!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText, height: 1.3),
                ),
                const SizedBox(height: 15),
                Text(
                  _selectedRole == UserRole.Admin ? 'Your admin account is pending approval.' : 'Your pharmacist account is pending approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Validators ---
  String? _validateNIC(String? value) {
    if (value == null || value.isEmpty) return 'NIC number is required';
    final nic = value.trim().toUpperCase();
    final nicRegex = RegExp(r'^(\d{9}[VX]|\d{12})$');
    if (!nicRegex.hasMatch(nic)) return 'Enter valid NIC (901234567V or 12 digits)';
    if (nic.length == 10) {
      final lastChar = nic.substring(9);
      if (lastChar != 'V' && lastChar != 'X') return 'Last character must be V or X';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // --- Compact input field (reduced height) ---
  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            enabled: enabled,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              prefixIcon: Icon(icon, color: AppColors.primaryPurple, size: 18),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: validator,
            onSaved: (value) {},
          ),
        ),
      ],
    );
  }

  // --- Role Dropdown (compact) ---
  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Role',
          style: TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: _isLoading ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple, size: 18),
            style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.w500),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            items: UserRole.values.map((UserRole role) {
              return DropdownMenuItem<UserRole>(
                value: role,
                child: Row(
                  children: [
                    Icon(
                      role == UserRole.Admin ? Icons.admin_panel_settings : Icons.medical_services,
                      color: AppColors.primaryPurple,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(role.name, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isLoading ? null : (UserRole? newValue) {
              if (newValue != null) setState(() => _selectedRole = newValue);
            },
          ),
        ),
      ],
    );
  }

  // --- Gradient Button (compact) ---
  Widget _buildGradientButton({required String text, required VoidCallback? onPressed, bool isLoading = false}) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isDisabled
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600])
              : const LinearGradient(
                  colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: isDisabled
              ? []
              : [BoxShadow(color: AppColors.buttonGradientEnd.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Minimal header (back button only)
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkText, size: 18),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // balance the back button
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Logo
                          Hero(
                            tag: 'app-logo',
                            child: Image.asset('assets/logo/logo.png', height: 120, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 12),
                          // Heading label (new)
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildRoleDropdown(),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'NIC Number',
                            hint: '901234567V / 12 digits',
                            icon: Icons.badge_outlined,
                            controller: TextEditingController(text: _nic),
                            validator: _validateNIC,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'Full Name',
                            hint: 'Your full name',
                            icon: Icons.person_outline_rounded,
                            controller: TextEditingController(text: _fullName),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Full name is required';
                              if (value.trim().length < 2) return 'Name must be at least 2 characters';
                              return null;
                            },
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'Email Address',
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            controller: TextEditingController(text: _email),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Email is required';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'Mobile Number',
                            hint: '07X XXX XXXX',
                            icon: Icons.phone_android_outlined,
                            controller: TextEditingController(text: _mobileNumber),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Mobile number is required';
                              if (value.length != 10) return 'Must be exactly 10 digits';
                              if (!value.startsWith('07')) return 'Must start with 07';
                              return null;
                            },
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'Password',
                            hint: 'At least 6 characters',
                            icon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            validator: _validatePassword,
                            enabled: !_isLoading,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.primaryPurple,
                                size: 18,
                              ),
                              onPressed: _isLoading ? null : () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInputField(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            icon: Icons.lock_reset_rounded,
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            validator: _validateConfirmPassword,
                            enabled: !_isLoading,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.primaryPurple,
                                size: 18,
                              ),
                              onPressed: _isLoading ? null : () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 12))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildGradientButton(
                            text: _isLoading ? 'Creating Account...' : 'Create Account',
                            onPressed: _isLoading ? null : _handleSignUp,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? ", style: TextStyle(fontSize: 12, color: AppColors.darkText)),
                              GestureDetector(
                                onTap: _isLoading ? null : () => Navigator.pop(context),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(fontSize: 12, color: AppColors.primaryPurple, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Developed By Malitha Tishamal', style: TextStyle(color: AppColors.darkText, fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}