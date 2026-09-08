import 'dart:convert';
import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final emailFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();
  final baseUrl = dotenv.env['API_BASE_URL']!;
  String? formError;
  String? emailError;
  String? confirmPasswordError;
  bool isLoading = false;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final errors = <String>[];

    if (name.isEmpty) {
      errors.add('Please enter your name');
    }

    if (email.isEmpty) {
      errors.add('Please enter your email');
    } else if (!email.toLowerCase().endsWith('@autuni.ac.nz')) {
      errors.add('Please use your AUT email (@autuni.ac.nz)');
    }

    if (password.isEmpty) {
      errors.add('Please enter a password');
    }

    if (confirmPassword.isEmpty) {
      errors.add('Please confirm your password');
    } else if (password != confirmPassword) {
      errors.add("Passwords don't match");
    }

    if (errors.isNotEmpty) {
      setState(() {
        formError = errors.map((error) => '• $error').join('\n');
      });
      return;
    }

    setState(() {
      formError = null;
      isLoading = true;
    });

    try {
      final checkResponse = await http.post(
        Uri.parse('$baseUrl/auth/check-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      if (!mounted) return;

      if (checkResponse.statusCode == 409) {
        setState(() {
          formError =
              '• This email is already registered.';
          isLoading = false;
        });
        return;
      }

      if (checkResponse.statusCode != 200) {
        setState(() {
          formError =
              '• Could not check email. Please try again.';
          isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),

        headers: {
          'Content-Type': 'application/json',
        },

        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              successMessage: data['message'],
            ),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['detail'] ?? 'Registration failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect to server: $e'),
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

    emailFocusNode.addListener(() {
      if (!emailFocusNode.hasFocus) {
        final email = emailController.text.trim();

        setState(() {
          if (email.isNotEmpty &&
              !email.toLowerCase().endsWith('@autuni.ac.nz')) {
            emailError = 'Please use your AUT email (@autuni.ac.nz)';
          } else {
            emailError = null;
          }
        });
      }
    });

    confirmPasswordFocusNode.addListener(() {
      if (!confirmPasswordFocusNode.hasFocus) {
        final password = passwordController.text;
        final confirmPassword = confirmPasswordController.text;

        setState(() {
          if (confirmPassword.isNotEmpty &&
              password != confirmPassword) {
            confirmPasswordError = "Passwords don't match";
          } else {
            confirmPasswordError = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/StudyBuddies_small_logo.png',
              width: 35,
              height: 35,
            ),
            const SizedBox(width: 8),
            const Text('Register'),
          ],
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 20,
        ),

        children: [          
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
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Text(
            'Name',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),

          TextField(
            controller: nameController,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
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
            focusNode: emailFocusNode,
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

          if (emailError != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                top: 4,
              ),
              child: Text(
                emailError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
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
              hintText: 'Enter a password',

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

          const SizedBox(height: 8),

          const Text(
            'Confirm Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),

          TextField(
            controller: confirmPasswordController,
            focusNode: confirmPasswordFocusNode,
            obscureText: !isConfirmPasswordVisible,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Confirm your password',
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
                  isConfirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.grey,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    isConfirmPasswordVisible = !isConfirmPasswordVisible;
                  });
                },
              ),
            ),
          ),

          if (confirmPasswordError != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                top: 4,
              ),
              child: Text(
                confirmPasswordError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 60),

          ElevatedButton(

            onPressed:
                isLoading ? null : register,

            child: Text(
              isLoading ? 'Creating account...' : 'Sign Up',
              style: const TextStyle( color: Colors.black, ),
            ),
          ),
        ],
      ),
    );
  }
}
