import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class PharmacistDashboard extends StatelessWidget {
  const PharmacistDashboard({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pharmacist Dashboard"), actions: [
        IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout))
      ]),
      body: const Center(child: Text("Welcome Pharmacist")),
    );
  }
}
