import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'signup_page.dart';
import 'dashboard_wrapper.dart';

// NOTE: For a real app, use SharedPreferences for persistent data storage.
// This simulates it temporarily using static variables.

class LoginThrottleManager {
  static const Map<int, int> _lockoutDurations = {
    3: 2,
    5: 5,
    6: 10,
    7: 20,
    8: 60,
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
    if (_lockoutEndTime != null && _lockoutEndTime!.isAfter(DateTime.now())) {
      final duration = _lockoutEndTime!.difference(DateTime.now());
      String remaining = '';
      if (duration.inHours > 0) {
        remaining += '${duration.inHours}h ';
      }
      if (duration.inMinutes.remainder(60) > 0) {
        remaining += '${duration.inMinutes.remainder(60)}m ';
      }
      remaining += '${duration.inSeconds.remainder(60)}s';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          _errorMessage = 'Your account status is "$accountStatus". Access is restricted until approval.';
        });
        return;
      }

      LoginThrottleManager.resetAttempts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful!')),
        );
        Navigator.of(context).pushReplacement(
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
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      if (_errorMessage == null && LoginThrottleManager.getLockoutMessage() != null) {
        setState(() {
          _errorMessage = LoginThrottleManager.getLockoutMessage();
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
              Image.asset('assets/logo.png', height: 250),
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
                'please login to continue using the app',
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Forgot Password feature coming soon!')),
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
              const SizedBox(height: 30),
              _buildGradientButton(
                text: _isLoading ? 'Logging In...' : 'Login',
                onPressed: _isLoading ? () {} : _handleLogin,
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
    return Container(
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
          onTap: onPressed,
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
              onPressed: () {
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
