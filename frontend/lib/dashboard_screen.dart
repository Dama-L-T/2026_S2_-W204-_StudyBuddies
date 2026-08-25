import 'package:flutter/material.dart';

import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String email;
  final String userId;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  void logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () => logout(context),
            child: const Text('Log out'),
          ),
        ],
      ),

      body: Center(
        child: Text(
          'Welcome, $email',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}