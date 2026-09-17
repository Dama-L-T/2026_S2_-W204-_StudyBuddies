import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../Schedule/schedule.page.dart';

class ProfilePage extends StatefulWidget {
  final String apiBaseUrl;
  final String accessToken;

  const ProfilePage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final personalDetailsController = TextEditingController();
  final coursesController = TextEditingController();
  final interestsController = TextEditingController();
  final preferencesController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  XFile? profileImage;

  Future<void> selectProfilePicture() async {
    final XFile? selectedImage = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (selectedImage == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      profileImage = selectedImage;
    });
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'personal_details': personalDetailsController.text.trim(),
          'courses': coursesController.text.trim(),
          'interests': interestsController.text.trim(),
          'preferences': preferencesController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => SchedulerScreen(
              apiBaseUrl: widget.apiBaseUrl,
              accessToken: widget.accessToken,
            ),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to the server.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    personalDetailsController.dispose();
    coursesController.dispose();
    interestsController.dispose();
    preferencesController.dispose();

    super.dispose();
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

            // PROFILE PICTURE
            Center(
              child: GestureDetector(
                onTap: selectProfilePicture,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey,
                      backgroundImage: profileImage != null
                          ? FileImage(File(profileImage!.path))
                          : null,
                      child: profileImage == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),

                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Center(
              child: Text(
                'Tap your picture to change it',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 30),

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
                hintText: 'e.g. COMP602, COMP604',
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
                hintText: 'e.g. Programming, AI, Cybersecurity',
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
                hintText: 'e.g. Study preferences, group work, etc.',
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