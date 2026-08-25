import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'register_screen.dart';
import 'dashboard_screen.dart';


class LoginScreen extends StatefulWidget {
  final String? successMessage;

  const LoginScreen({
    super.key,
    this.successMessage,
  });


  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool isLoading = false;


  Future<void> login() async {

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;


    if (email.isEmpty || password.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter email and password',
          ),
        ),
      );

      return;
    }


    setState(() {
      isLoading = true;
    });


    try {

      final response = await http.post(
        Uri.parse(
          'http://10.0.2.2:8000/auth/login',
        ),

        headers: {
          'Content-Type': 'application/json',
        },

        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );


      final data = jsonDecode(
        response.body,
      );


      if (!mounted) return;


      if (response.statusCode == 200) {

        final user = data['user'];

        Navigator.pushReplacement(
          context,

          MaterialPageRoute(
            builder: (context) =>
                DashboardScreen(
              userId: user['id'],
              email: user['email'],
            ),
          ),
        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['detail'] ??
                  'Login failed',
            ),
          ),
        );
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect to server: $e',
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.successMessage!),
          ),
        );
      }
    });
  }

  @override
  void dispose() {

    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Login'),
      ),

      body: ListView(

        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 50,
        ),

        children: [

          TextField(
            controller: emailController,

            keyboardType:
                TextInputType.emailAddress,

            decoration: const InputDecoration(
              labelText: 'Email',
            ),
          ),


          TextField(
            controller: passwordController,

            obscureText: true,

            decoration: const InputDecoration(
              labelText: 'Password',
            ),
          ),


          const SizedBox(height: 12),


          ElevatedButton(

            onPressed:
                isLoading ? null : login,

            child: Text(
              isLoading
                  ? 'Logging in...'
                  : 'Login',
            ),
          ),


          const SizedBox(height: 12),


          Center(

            child: GestureDetector(

              onTap: () {

                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (context) =>
                        const RegisterScreen(),
                  ),
                );
              },

              child: const Text(
                "Don't have an account? Sign up",
              ),
            ),
          ),
        ],
      ),
    );
  }
}