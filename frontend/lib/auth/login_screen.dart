import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'register_screen.dart';
import '../Schedule/schedule.page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final baseUrl = dotenv.env['API_BASE_URL']!;
  bool isLoading = false;
  bool isPasswordVisible = false;
  String? formError;
  String? successMessage;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final errors = <String>[];

    if (email.isEmpty) {
      errors.add('Please enter your email');
    } else if (!email.toLowerCase().endsWith('@autuni.ac.nz')) {
      errors.add(
        'Please use your AUT email (@autuni.ac.nz)',
      );
    }

    if (password.isEmpty) {
      errors.add('Please enter your password');
    }

    if (errors.isNotEmpty) {
      setState(() {
        formError = errors.map((error) => '• $error').join('\n');
      });
      return;
    }

    setState(() {
      formError = null;
      successMessage = null;
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SchedulerScreen(
              apiBaseUrl: baseUrl,
              accessToken: data['access_token'],
            ),
          ),
        );

      } else {
          setState(() {
            formError = '• Invalid email or password';
          });
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
        setState(() {
          successMessage = widget.successMessage;
        });
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
      backgroundColor: Colors.black,

      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 0,
        ),

        children: [
          Image.asset(
            'assets/StudyBuddies_logo.png',
            height: 200,
          ),

          const SizedBox(height: 30),
          if (successMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(
                  color: Colors.green,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      successMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (formError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(
                  color: Colors.red,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          const Text(
            'Email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          
          TextField(
            controller: emailController,

            keyboardType: TextInputType.emailAddress,

            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),

            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),


          TextField(
            controller: passwordController,

            obscureText: !isPasswordVisible,
            
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),

            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.grey,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    isPasswordVisible = !isPasswordVisible;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 60),

          ElevatedButton(
            onPressed:
                isLoading ? null : login,

            child: Text(
              isLoading ? 'Logging in...' : 'Login',
              style: const TextStyle( color: Colors.black, ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
