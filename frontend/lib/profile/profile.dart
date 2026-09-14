import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final personalDetailsController = TextEditingController();
  final coursesController = TextEditingController();
  final interestsController = TextEditingController();
  final preferencesController = TextEditingController();

  final baseUrl = dotenv.env['API_BASE_URL']!;

  Future<void> saveProfile() async {
  final response = await http.post(
    Uri.parse('$baseUrl/profile/'),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': nameController.text,
      'personal_details': personalDetailsController.text,
      'courses': coursesController.text,
      'interests': interestsController.text,
      'preferences': preferencesController.text,
    }),
  );

  if (!mounted) return;

  if (response.statusCode == 200) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved!'),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to save profile.'),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Your Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            // NAME
            const Text(
              'Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
              ),
            ),

            const SizedBox(height: 20),

            // PERSONAL DETAILS
            const Text(
              'Personal Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            TextField(
              controller: personalDetailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tell us a little about yourself',
              ),
            ),

            const SizedBox(height: 20),

            // COURSES
            const Text(
              'Courses',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            TextField(
              controller: coursesController,
              decoration: const InputDecoration(
                hintText: 'ex. COMP602, COMP604',
              ),
            ),

            const SizedBox(height: 20),

            // INTERESTS
            const Text(
              'Interests',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            TextField(
              controller: interestsController,
              decoration: const InputDecoration(
                hintText: 'ex. Programming, AI, Cybersecurity',
              ),
            ),

            const SizedBox(height: 20),

            // PREFERENCES
            const Text(
              'Preferences',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            TextField(
              controller: preferencesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ex. Study preferences, group work, etc.',
              ),
            ),

            const SizedBox(height: 30),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveProfile,
                child: const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
