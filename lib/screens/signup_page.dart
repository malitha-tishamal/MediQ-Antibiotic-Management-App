import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  String _role = "admin";
  bool _loading = false;

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _signup() async {
    if (_emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty ||
        _confirmPasswordCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty ||
        _nicCtrl.text.trim().isEmpty ||
        _mobileCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (_passwordCtrl.text.trim() != _confirmPasswordCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Firebase Auth signup
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text.trim());

      // Firestore user info
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        "name": _nameCtrl.text.trim(),
        "nic": _nicCtrl.text.trim(),
        "mobile": _mobileCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "role": _role,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Signup failed")));
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/icon.png', height: 160),
                const SizedBox(height: 20),
                const Text("Sign Up",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                DropdownButtonFormField(
                  value: _role,
                  decoration: _inputDecoration("User Type"),
                  items: const [
                    DropdownMenuItem(value: "admin", child: Text("Admin")),
                    DropdownMenuItem(value: "pharmacist", child: Text("Pharmacist")),
                  ],
                  onChanged: (val) => setState(() => _role = val.toString()),
                ),
                const SizedBox(height: 12),
                TextField(controller: _nicCtrl, decoration: _inputDecoration("NIC Number")),
                const SizedBox(height: 12),
                TextField(controller: _nameCtrl, decoration: _inputDecoration("Your Name")),
                const SizedBox(height: 12),
                TextField(controller: _emailCtrl, decoration: _inputDecoration("Email")),
                const SizedBox(height: 12),
                TextField(controller: _mobileCtrl, decoration: _inputDecoration("Mobile Number")),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    "Password",
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirmPassword,
                  decoration: _inputDecoration(
                    "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(onPressed: _signup, child: const Text("Sign Up")),
                      ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginPage()));
                  },
                  child: const Text("Already Registered? Sign In"),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Developed By Malitha Tishamal",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
