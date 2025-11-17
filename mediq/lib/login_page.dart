import 'dart:async'; // Added for Timer functionality
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Assumed to contain AppColors
import 'signup_page.dart';
import 'dashboard_wrapper.dart';

// NOTE: For a real app, persistent storage (like SharedPreferences) should be used
// for failedAttempts and lockoutEndTime to survive app restarts.
// This implements the real-time countdown logic for a better user experience
// once the lockout is active within the current session.

class LoginThrottleManager {
  static const Map<int, int> _lockoutDurations = {
    3: 2, // 3 failed attempts: 2 minutes lockout
    5: 5, // 5 failed attempts: 5 minutes lockout
    6: 10, // 6 failed attempts: 10 minutes lockout
    7: 20, // 7 failed attempts: 20 minutes lockout
    8: 60, // 8+ failed attempts: 60 minutes lockout
  };

  static int _failedAttempts = 0;
  static DateTime? _lockoutEndTime;

  static int get failedAttempts => _failedAttempts;
  static DateTime? get lockoutEndTime => _lockoutEndTime;

  static void recordFailedAttempt() {
    _failedAttempts++;
    int durationMinutes = 0;

    if (_failedAttempts >= 8) {
      durationMinutes = 60;
    } else if (_lockoutDurations.containsKey(_failedAttempts)) {
      durationMinutes = _lockoutDurations[_failedAttempts]!;
    }

    if (durationMinutes > 0) {
      _lockoutEndTime = DateTime.now().add(Duration(minutes: durationMinutes));
    }

    debugPrint('Login failed. Attempts: $_failedAttempts. Lockout ends: $_lockoutEndTime');
  }

  static void resetAttempts() {
    _failedAttempts = 0;
    _lockoutEndTime = null;
    debugPrint('Login successful. Attempts reset.');
  }

  static String? getLockoutMessage() {
    if (_lockoutEndTime != null && _lockoutEndTime!.isBefore(DateTime.now())) {
      _lockoutEndTime = null;
      return null;
    }

    if (_lockoutEndTime != null) {
      final duration = _lockoutEndTime!.difference(DateTime.now());
      String remaining = '';

      if (duration.inHours > 0) {
        remaining += '${duration.inHours}h ';
      }
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      remaining += '${minutes.toString().padLeft(2, '0')}m ';
      remaining += '${seconds.toString().padLeft(2, '0')}s';

      return 'Too many failed attempts. Try again in $remaining.';
    }
    return null;
  }
}

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

  @override
  void initState() {
    super.initState();
    _startLockoutTimer();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    if (LoginThrottleManager.getLockoutMessage() != null) {
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final newLockoutMessage = LoginThrottleManager.getLockoutMessage();
        if (newLockoutMessage == null) {
          timer.cancel();
        }
        if (mounted) {
          setState(() {
            _errorMessage = newLockoutMessage;
          });
        }
      });
    }
  }

  void _handleLogin() async {
    final lockoutMessage = LoginThrottleManager.getLockoutMessage();
    if (lockoutMessage != null) {
      setState(() {
        _errorMessage = lockoutMessage;
      });
      return;
    }

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

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("User object is null after successful login.");

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        setState(() {
          _errorMessage = 'User profile data not found. Please contact support.';
        });
        return;
      }

      final accountStatus = userDoc.data()?['status'];
      if (accountStatus != 'Approved') {
        await _auth.signOut();
        setState(() {
          _errorMessage =
              'Your account status is "$accountStatus". Access is restricted until approval.';
        });
        return;
      }

      LoginThrottleManager.resetAttempts();
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
      LoginThrottleManager.recordFailedAttempt();

      String message;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Login Error: ${e.message}';
      }

      final newLockoutMessage = LoginThrottleManager.getLockoutMessage();
      if (newLockoutMessage != null) {
        message = newLockoutMessage;
        _startLockoutTimer();
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _errorMessage ?? LoginThrottleManager.getLockoutMessage();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 50),
              Image.asset(
                'assets/logo.png',
                height: 250,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.lock, size: 100, color: AppColors.primaryPurple);
                },
              ),
              const SizedBox(height: 30),
              const Text(
                'Login In Now',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Please login to continue using the app',
                style: TextStyle(color: AppColors.darkText, fontSize: 14),
              ),
              const SizedBox(height: 40),
              _buildInputField(
                label: 'Enter Your Email',
                hint: 'example@email.com',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 20),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Forgot Password feature coming soon!')),
                          );
                        },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
              const SizedBox(height: 30),
              _buildGradientButton(
                text: _isLoading ? 'Logging In...' : 'Login',
                onPressed: (_isLoading || LoginThrottleManager.getLockoutMessage() != null)
                    ? () {}
                    : _handleLogin,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have account ? ",
                    style: TextStyle(fontSize: 14, color: AppColors.darkText),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_isLoading || LoginThrottleManager.getLockoutMessage() != null) return;
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
                        decorationColor: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Developed By Malitha Tishamal',
                  style: TextStyle(color: AppColors.darkText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onPressed}) {
    final bool isButtonDisabled =
        (text == 'Logging In...' || LoginThrottleManager.getLockoutMessage() != null);

    return Opacity(
      opacity: isButtonDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
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
            onTap: isButtonDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: Text(
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: LoginThrottleManager.getLockoutMessage() != null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: Icon(icon, color: AppColors.inputBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          readOnly: LoginThrottleManager.getLockoutMessage() != null,
          decoration: InputDecoration(
            hintText: '*********',
            hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.primaryPurple,
              ),
              onPressed: LoginThrottleManager.getLockoutMessage() != null
                  ? null
                  : () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
        ),
      ],
    );
  }
}
