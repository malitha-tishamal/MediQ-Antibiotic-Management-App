import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'login_page.dart'; // Make sure to import your login page

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
  
  // Controllers for real-time validation
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State variables
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

  // UPDATED: Function to get default profile picture with correct asset paths
  Future<String?> _getDefaultProfilePicture() async {
    try {
      String assetPath;
      
      if (_selectedRole == UserRole.Admin) {
        assetPath = 'assets/admin-default.jpg';
      } else {
        assetPath = 'assets/pharmacist-default.jpg';
      }

      debugPrint('🖼️ Loading default profile picture from: $assetPath');

      // Load asset as bytes
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Convert to base64
      final String base64String = base64Encode(bytes);
      
      debugPrint('✅ Successfully loaded default profile picture for ${_selectedRole.name}');
      debugPrint('📊 Base64 length: ${base64String.length} characters');
      
      return base64String;
    } catch (e) {
      debugPrint('❌ Failed to load default profile picture: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      // Return empty string if image loading fails
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
      // Get default profile picture based on role
      final String? defaultProfileImage = await _getDefaultProfilePicture();
      
      final UserCredential userCredential = 
          await _auth.createUserWithEmailAndPassword(
        email: _email.trim(),
        password: _password,
      );

      // Firestore document data
      final userData = {
        'email': _email.trim(),
        'role': _selectedRole.name,
        'fullName': _fullName.trim(),
        'nic': _nic.trim().toUpperCase(),
        'mobileNumber': _mobileNumber.trim(),
        'status': 'Pending',
        'profileImage': defaultProfileImage ?? '', // Use default image or empty string
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('🔥 Creating user document in Firestore...');
      debugPrint('👤 Role: ${_selectedRole.name}');
      debugPrint('📧 Email: ${_email.trim()}');
      debugPrint('👤 Full Name: ${_fullName.trim()}');
      debugPrint('🆔 NIC: ${_nic.trim().toUpperCase()}');
      debugPrint('📱 Mobile: ${_mobileNumber.trim()}');
      debugPrint('🖼️ Profile image set: ${defaultProfileImage != null && defaultProfileImage!.isNotEmpty}');

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);

      debugPrint('✅ User document created successfully');
      debugPrint('👤 User UID: ${userCredential.user!.uid}');

      if (mounted) {
        await _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleGenericError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        message = 'Email/password accounts are not enabled. Please contact support.';
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
      default:
        message = 'Registration failed: ${e.message}';
    }
    
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  void _handleGenericError(dynamic e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
    debugPrint('SignUp Error: $e');
  }

  // UPDATED: Success dialog that navigates to login page
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
                // Show role-specific icon in success dialog
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _selectedRole == UserRole.Admin 
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedRole == UserRole.Admin 
                        ? Icons.admin_panel_settings 
                        : Icons.medical_services,
                    color: _selectedRole == UserRole.Admin 
                        ? Colors.purple 
                        : Colors.blue,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  '${_selectedRole.name} Account Created\nSuccessfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _selectedRole == UserRole.Admin 
                      ? 'Your admin account is pending approval.'
                      : 'Your pharmacist account is pending approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 25),
                _buildGradientButton(
                  text: 'Continue to Login',
                  onPressed: () {
                    // Close the dialog
                    Navigator.of(context).pop();
                    // Navigate to login page and remove all previous routes
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  isLoading: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _validateNIC(String? value) {
    if (value == null || value.isEmpty) {
      return 'NIC number is required';
    }
    
    final nic = value.trim().toUpperCase();
    final nicRegex = RegExp(r'^(\d{9}[VX]|\d{12})$');
    
    if (!nicRegex.hasMatch(nic)) {
      return 'Enter valid NIC (901234567V or 12 digits)';
    }
    
    if (nic.length == 10) {
      final lastChar = nic.substring(9);
      if (lastChar != 'V' && lastChar != 'X') {
        return 'Last character must be V or X';
      }
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    bool isEnabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: isEnabled ? AppColors.darkText : Colors.grey.shade600,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isEnabled ? Colors.white : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(
            prefixIcon, 
            color: isEnabled ? AppColors.primaryPurple : Colors.grey.shade400, 
            size: 22
          ),
        ),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Role',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder, width: 1.5),
            color: _isLoading ? Colors.grey.shade100 : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<UserRole>(
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              value: _selectedRole,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, 
                  color: AppColors.primaryPurple),
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: UserRole.values.map((UserRole role) {
                return DropdownMenuItem<UserRole>(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == UserRole.Admin 
                            ? Icons.admin_panel_settings 
                            : Icons.medical_services,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        role.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isLoading ? null : (UserRole? newValue) {
                if (newValue != null) {
                  setState(() => _selectedRole = newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: onPressed == null || isLoading
              ? [Colors.grey.shade400, Colors.grey.shade600]
              : const [
                  AppColors.buttonGradientStart,
                  AppColors.buttonGradientEnd,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: onPressed == null || isLoading
            ? []
            : [
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 20),
                    // Header with back button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.darkText),
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Logo
                    Hero(
                      tag: 'app-logo',
                      child: Image.asset(
                        'assets/logo.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Form fields
                    _buildRoleDropdown(),
                    const SizedBox(height: 20),
                    // NIC Field
                    TextFormField(
                      decoration: _inputDecoration(
                        label: 'NIC Number',
                        hintText: 'e.g., 901234567V or 202312345678',
                        prefixIcon: Icons.badge_outlined,
                        isEnabled: !_isLoading,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onSaved: (value) => _nic = value!.trim().toUpperCase(),
                      validator: _validateNIC,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),
                    // Full Name Field
                    TextFormField(
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icons.person_outline_rounded,
                        isEnabled: !_isLoading,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSaved: (value) => _fullName = value!.trim(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),
                    // Email Field
                    TextFormField(
                      decoration: _inputDecoration(
                        label: 'Email Address',
                        hintText: 'example@email.com',
                        prefixIcon: Icons.email_outlined,
                        isEnabled: !_isLoading,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (value) => _email = value!.trim(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),
                    // Mobile Number Field
                    TextFormField(
                      decoration: _inputDecoration(
                        label: 'Mobile Number',
                        hintText: '07X XXX XXXX',
                        prefixIcon: Icons.phone_android_outlined,
                        isEnabled: !_isLoading,
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onSaved: (value) => _mobileNumber = value!.trim(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mobile number is required';
                        }
                        if (value.length != 10) {
                          return 'Must be exactly 10 digits';
                        }
                        if (!value.startsWith('07')) {
                          return 'Must start with 07';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: _inputDecoration(
                        label: 'Password',
                        hintText: 'At least 6 characters',
                        prefixIcon: Icons.lock_outline_rounded,
                        isEnabled: !_isLoading,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible 
                                ? Icons.visibility_off_rounded 
                                : Icons.visibility_rounded,
                            color: AppColors.primaryPurple,
                          ),
                          onPressed: _isLoading ? null : () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      onSaved: (value) => _password = value!,
                      validator: _validatePassword,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: _inputDecoration(
                        label: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: Icons.lock_reset_rounded,
                        isEnabled: !_isLoading,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible 
                                ? Icons.visibility_off_rounded 
                                : Icons.visibility_rounded,
                            color: AppColors.primaryPurple,
                          ),
                          onPressed: _isLoading ? null : () => setState(() => 
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                        ),
                      ),
                      onSaved: (value) => _confirmPassword = value!,
                      validator: _validateConfirmPassword,
                      enabled: !_isLoading,
                    ),
                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, 
                                color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    // Sign Up Button
                    _buildGradientButton(
                      text: _isLoading ? 'Creating Account...' : 'Create Account',
                      onPressed: _isLoading ? null : _handleSignUp,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 25),
                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.darkText,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
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
          ),
        ),
      ),
    );
  }
}