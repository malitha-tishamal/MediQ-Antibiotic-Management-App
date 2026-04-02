import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // AppColors
import 'signup_page.dart';
import '../core/dashboard_wrapper.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _lockoutTimer;

  // Helper to get lockout duration in seconds based on failed attempts
  int _getLockoutDuration(int attempts) {
    switch (attempts) {
      case 3:
        return 30;
      case 4:
        return 60;
      case 5:
        return 180;
      case 6:
        return 600;
      case 7:
        return 1800;
      default:
        return 0;
    }
  }

  // Fetch user document by email (requires an index on email)
  Future<DocumentSnapshot?> _getUserDocByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user by email: $e');
      return null;
    }
  }

  // Update failed attempts and lockout state for the user
  Future<void> _recordFailedAttempt(String email) async {
    final userDoc = await _getUserDocByEmail(email);
    if (userDoc == null) return; // No user document, cannot record

    final data = userDoc.data() as Map<String, dynamic>;
    int attempts = (data['failedLoginAttempts'] ?? 0) + 1;
    String status = data['status'] ?? 'Approved';
    Timestamp? lockoutUntil = data['lockoutUntil'];

    // If already locked, do nothing (should have been caught earlier)
    if (status == 'Locked') return;

    // Determine new state
    if (attempts >= 8) {
      // Account lock
      status = 'Locked';
      lockoutUntil = null;
    } else {
      final duration = _getLockoutDuration(attempts);
      if (duration > 0) {
        lockoutUntil = Timestamp.fromDate(
          DateTime.now().add(Duration(seconds: duration)),
        );
      } else {
        lockoutUntil = null;
      }
    }

    await userDoc.reference.update({
      'failedLoginAttempts': attempts,
      'lockoutUntil': lockoutUntil,
      'status': status,
    });
  }

  // Reset attempts on successful login
  Future<void> _resetFailedAttempts(String email) async {
    final userDoc = await _getUserDocByEmail(email);
    if (userDoc == null) return;
    await userDoc.reference.update({
      'failedLoginAttempts': 0,
      'lockoutUntil': null,
    });
  }

  // Check if the user is locked out (either account locked or temporary lockout)
  Future<({bool isLocked, String? message, DateTime? lockoutEnd})> _checkLockoutStatus(
      String email) async {
    final userDoc = await _getUserDocByEmail(email);
    if (userDoc == null) {
      return (isLocked: false, message: null, lockoutEnd: null);
    }

    final data = userDoc.data() as Map<String, dynamic>;
    final status = data['status'] as String?;
    final lockoutUntil = data['lockoutUntil'] as Timestamp?;

    // Account permanently locked
    if (status == 'Locked') {
      return (
        isLocked: true,
        message: 'Your account has been locked. Please contact admin for approval.',
        lockoutEnd: null
      );
    }

    // Temporary lockout
    if (lockoutUntil != null) {
      final lockoutDateTime = lockoutUntil.toDate();
      if (lockoutDateTime.isAfter(DateTime.now())) {
        return (
          isLocked: true,
          message: 'Too many failed attempts. Try again later.',
          lockoutEnd: lockoutDateTime
        );
      } else {
        // Lockout expired, we could reset the lockout field, but leave attempts count for next failure
        await userDoc.reference.update({'lockoutUntil': null});
      }
    }

    return (isLocked: false, message: null, lockoutEnd: null);
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    if (_errorMessage != null && _errorMessage!.contains('Try again in')) {
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Re‑evaluate lockout status to update remaining time
        _updateLockoutMessage();
      });
    }
  }

  Future<void> _updateLockoutMessage() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final status = await _checkLockoutStatus(email);
    if (status.isLocked && status.lockoutEnd != null) {
      final remaining = status.lockoutEnd!.difference(DateTime.now());
      if (remaining.isNegative) {
        // Lockout expired, clear message
        if (mounted) setState(() => _errorMessage = null);
        _lockoutTimer?.cancel();
      } else {
        String formatted = '';
        if (remaining.inHours > 0) formatted += '${remaining.inHours}h ';
        final minutes = remaining.inMinutes.remainder(60);
        final seconds = remaining.inSeconds.remainder(60);
        formatted += '${minutes.toString().padLeft(2, '0')}m ';
        formatted += '${seconds.toString().padLeft(2, '0')}s';
        if (mounted) {
          setState(() {
            _errorMessage = 'Too many failed attempts. Try again in $formatted.';
          });
        }
      }
    } else if (status.isLocked && status.lockoutEnd == null) {
      if (mounted) setState(() => _errorMessage = status.message);
      _lockoutTimer?.cancel();
    } else {
      // No lockout, clear message if it was a lockout message
      if (_errorMessage != null &&
          (_errorMessage!.contains('Try again in') ||
              _errorMessage!.contains('account has been locked'))) {
        if (mounted) setState(() => _errorMessage = null);
      }
      _lockoutTimer?.cancel();
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password.';
        _isLoading = false;
      });
      return;
    }

    // Check lockout status before attempting sign-in
    final lockoutStatus = await _checkLockoutStatus(email);
    if (lockoutStatus.isLocked) {
      setState(() {
        _errorMessage = lockoutStatus.message;
        _isLoading = false;
      });
      if (lockoutStatus.lockoutEnd != null) _startLockoutTimer();
      return;
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("User object is null.");

      // Fetch user document (by UID) to check status again (safety)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        setState(() {
          _errorMessage = 'User profile not found. Contact support.';
        });
        return;
      }

      final accountStatus = userDoc.data()?['status'];
      if (accountStatus != 'Approved') {
        await _auth.signOut();
        setState(() {
          _errorMessage =
              'Your account status is "$accountStatus". Access restricted until approval.';
        });
        return;
      }

      // Reset failed attempts on successful login
      await _resetFailedAttempts(email);

      _lockoutTimer?.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful!')),
        );
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardWrapper()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Record failed attempt only for wrong password or user not found (which indicates existing user)
      if (e.code == 'wrong-password') {
        await _recordFailedAttempt(email);
        // Re‑check lockout after recording
        final newLockout = await _checkLockoutStatus(email);
        if (newLockout.isLocked) {
          setState(() {
            _errorMessage = newLockout.message;
          });
          if (newLockout.lockoutEnd != null) _startLockoutTimer();
        } else {
          setState(() {
            _errorMessage = 'Invalid email or password.';
          });
        }
      } else if (e.code == 'user-not-found') {
        // Email doesn't exist in Auth, likely not registered. Don't record attempt.
        setState(() {
          _errorMessage = 'Invalid email or password.';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          _errorMessage = 'The email address is not valid.';
        });
      } else {
        setState(() {
          _errorMessage = 'Login Error: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Check lockout status on initial load (if email already entered)
    _emailController.addListener(() {
      // Optional: you could call _updateLockoutMessage here to update UI as user types
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 30),
                    Image.asset(
                      'assets/logo/logo.png',
                      height: 200,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.lock, size: 100, color: AppColors.primaryPurple),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Login In Now',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Please login to continue using the app',
                      style: TextStyle(color: AppColors.darkText, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    _buildInputField(
                      label: 'Enter Your Email',
                      hint: 'example@email.com',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordInput(),
                    const SizedBox(height: 10),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildGradientButton(
                      text: _isLoading ? 'Logging In...' : 'Login',
                      onPressed: _isLoading ? null : _handleLogin,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have account? ",
                          style: TextStyle(fontSize: 14, color: AppColors.darkText),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                                  );
                                },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Fixed footer
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
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback? onPressed}) {
    final bool isButtonDisabled = onPressed == null;
    return Opacity(
      opacity: isButtonDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isButtonDisabled
                ? [Colors.grey.shade400, Colors.grey.shade600]
                : const [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: isButtonDisabled
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
              child: Text(
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(icon, color: AppColors.primaryPurple, size: 20),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Your Password',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: '*********',
            hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.lock_outline_rounded, color: AppColors.primaryPurple, size: 20),
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          ),
        ),
      ],
    );
  }
}