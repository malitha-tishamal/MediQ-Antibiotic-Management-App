import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // Import AppColors

// Define the available roles for the dropdown
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

  // State variables for all required fields
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _nic = '';
  String _fullName = '';
  String _mobileNumber = '';
  UserRole _selectedRole = UserRole.Pharmacist; // Default role
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

  // Function to handle the sign-up process
  void _handleSignUp() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_password != _confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Create User with Email and Password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      // 2. Save User Profile Data and Role to Firestore
      // IMPORTANT: Added 'status' field and set it to 'Pending'.
      // Added 'profileImage' field with empty string as default value
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _email,
        'role': _selectedRole.name,
        'fullName': _fullName,
        'nic': _nic,
        'mobileNumber': _mobileNumber,
        'status': 'Pending', // <-- New default status
        'profileImage': '', // <-- Add this line for profile image (empty by default)
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Show Success Message and Navigate back to Login
      if (mounted) {
        _showSuccessDialog();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close dialog
            Navigator.pop(context); // Go back to LoginPage
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else {
        message = 'Registration Error: ${e.message}';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'An unexpected error occurred during registration.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Success Dialog ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 80),
              const SizedBox(height: 20),
              Text(
                'Create Account\nSuccess',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint, IconData prefixIcon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.inputBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.inputBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.primaryPurple, width: 2.0),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 10.0),
        child: Icon(prefixIcon, color: AppColors.inputBorder),
      ),
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: keyboardType,
          onSaved: onSaved,
          validator: validator,
          inputFormatters: inputFormatters,
          decoration: _inputDecoration(hint, icon),
        ),
      ],
    );
  }

  Widget _buildPasswordInput({
    required String label,
    required String hint,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    required bool isVisible,
    required VoidCallback toggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: !isVisible,
          onSaved: onSaved,
          validator: validator,
          decoration: _inputDecoration(
            hint,
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.primaryPurple,
              ),
              onPressed: toggleVisibility,
            ),
          ),
          onChanged: (label == 'Enter Your Password')
              ? (value) => _password = value
              : null,
        ),
      ],
    );
  }

  Widget _buildGradientButton(
      {required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Role',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<UserRole>(
          decoration: _inputDecoration('Select Your Role', Icons.group_outlined),
          value: _selectedRole,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.primaryPurple),
          style: const TextStyle(color: AppColors.darkText, fontSize: 16),
          dropdownColor: Colors.white,
          items: UserRole.values.map((UserRole role) {
            return DropdownMenuItem<UserRole>(
              value: role,
              child: Text(role.name),
            );
          }).toList(),
          onChanged: (UserRole? newValue) {
            setState(() {
              _selectedRole = newValue!;
            });
          },
          validator: (value) {
            if (value == null) return 'Role selection is required.';
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 100),
                  Image.asset(
                    'assets/logo.png',
                    height: 180,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Register Your Account',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fill in the details to create a new user',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildRoleDropdown(),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Enter Your NIC',
                    hint: 'NIC Number (e.g., 901234567V or 202312345678)',
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.text,
                    onSaved: (value) => _nic = value!,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'NIC number is required.';
                      }
                      final nicRegex = RegExp(r'^(\d{9}[Vv]|\d{12})$');
                      if (!nicRegex.hasMatch(value)) {
                        return 'Enter a valid NIC (901234567V or 12 digits).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Enter Your Name',
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.name,
                    onSaved: (value) => _fullName = value!,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Full name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Enter Your Email',
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (value) => _email = value!,
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return 'Enter a valid email.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Enter Your Mobile Number',
                    hint: 'Mobile Number (10 digits)',
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onSaved: (value) => _mobileNumber = value!,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Mobile number is required.';
                      }
                      if (value.length != 10) {
                        return 'Mobile number must be exactly 10 digits.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordInput(
                    label: 'Enter Your Password',
                    hint: '********* (Min 6 characters)',
                    onSaved: (value) => _password = value!,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                    isVisible: _isPasswordVisible,
                    toggleVisibility: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordInput(
                    label: 'Re-Enter Your Password',
                    hint: '********* (Must match above)',
                    onSaved: (value) => _confirmPassword = value!,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password.';
                      }
                      if (value != _password) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                    isVisible: _isConfirmPasswordVisible,
                    toggleVisibility: () {
                      setState(() => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildGradientButton(
                    text: _isLoading ? 'Registering...' : 'Sign Up',
                    onPressed: _isLoading ? () {} : _handleSignUp,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already Registered? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.darkText,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
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
    );
  }
}