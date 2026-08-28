import 'dart:convert';
import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;



class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});


  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}


class _RegisterScreenState
    extends State<RegisterScreen> {

  final nameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final confirmPasswordController =
      TextEditingController();

  bool isLoading = false;


  Future<void> register() async {

    final name =
        nameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    final confirmPassword =
        confirmPasswordController.text;


    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields',
          ),
        ),
      );

      return;
    }


    if (password != confirmPassword) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Passwords don't match",
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
          'http://10.0.2.2:8000/auth/register',
        ),

        headers: {
          'Content-Type': 'application/json',
        },

        body: jsonEncode({

          'name': name,

          'email': email,

          'password': password,
        }),
      );


      final data =
          jsonDecode(response.body);


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
              data['detail'] ??
                  'Registration failed',
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
  void dispose() {

    nameController.dispose();

    emailController.dispose();

    passwordController.dispose();

    confirmPasswordController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Sign Up'),
      ),

      body: ListView(

        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 50,
        ),

        children: [

          TextField(
            controller: nameController,

            decoration: const InputDecoration(
              labelText: 'Name',
            ),
          ),


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


          TextField(
            controller:
                confirmPasswordController,

            obscureText: true,

            decoration: const InputDecoration(
              labelText: 'Confirm Password',
            ),
          ),


          const SizedBox(height: 12),


          ElevatedButton(

            onPressed:
                isLoading ? null : register,

            child: Text(
              isLoading
                  ? 'Creating account...'
                  : 'Sign Up',
            ),
          ),
        ],
      ),
    );
  }
}