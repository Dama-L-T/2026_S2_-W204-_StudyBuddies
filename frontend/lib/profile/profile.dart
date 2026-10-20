import 'dart:convert';
import 'dart:io';

import 'student_profile.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  final String apiBaseUrl;
  final String accessToken;
  final VoidCallback onProfileSaved;
  final StudentProfile? viewedProfile;

  const ProfilePage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.onProfileSaved,
    this.viewedProfile,
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

  final List<String> _availableLanguages = const [
    'English',
    'Vietnamese',
    'Mandarin',
    'Hindi',
    'Japanese',
    'Korean',
    'French',
    'Spanish',
    'Other',
  ];

  final Set<String> _selectedLanguages = {};

  XFile? profileImage;
  String? _savedImageUrl;

  bool isLoading = true;
  bool isSaving = false;
  bool _hasChanges = false;

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.viewedProfile case final profile?) {
      _populateProfile(profile);
      isLoading = false;
    } else {
      loadProfile();
    }
  }

  void _populateProfile(StudentProfile profile) {
    nameController.text = profile.name;
    personalDetailsController.text = profile.personalDetails;
    coursesController.text = profile.courses;
    interestsController.text = profile.interests;
    preferencesController.text = profile.preferences;

    _selectedLanguages
      ..clear()
      ..addAll(StudentProfile.values(profile.languages));

    _savedImageUrl = profile.imageUrl;
  }

  Future<void> loadProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/profile/'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _populateProfile(
            StudentProfile.fromJson(Map<String, dynamic>.from(data as Map)),
          );
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your profile.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to the server.')),
      );
    }
  }

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
      _hasChanges = true;
    });
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode(
          StudentProfile(
            name: nameController.text.trim(),
            personalDetails: personalDetailsController.text.trim(),
            courses: coursesController.text.trim(),
            interests: interestsController.text.trim(),
            preferences: preferencesController.text.trim(),
            languages: _selectedLanguages.join(', '),
          ).toJson(),
        ),
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );

        setState(() {
          _hasChanges = false;
        });

        widget.onProfileSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save profile. '
              'Server returned ${response.statusCode}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to the server.')),
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
        title: Text(
          widget.viewedProfile == null ? 'My Profile' : 'Student Profile',
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.viewedProfile == null
                        ? 'My Profile'
                        : (nameController.text.isEmpty
                              ? 'Student'
                              : nameController.text),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Center(
                    child: GestureDetector(
                      onTap: widget.viewedProfile == null
                          ? selectProfilePicture
                          : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey,
                            backgroundImage: profileImage != null
                                ? FileImage(File(profileImage!.path))
                                : (_savedImageUrl != null
                                      ? NetworkImage(_savedImageUrl!)
                                      : null),
                            onBackgroundImageError:
                                _savedImageUrl != null && profileImage == null
                                ? (_, _) {}
                                : null,
                            child:
                                profileImage == null && _savedImageUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          if (widget.viewedProfile == null)
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

                  if (widget.viewedProfile == null)
                    const Center(
                      child: Text(
                        'Tap your picture to change it',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 30),

                  if (widget.viewedProfile == null ||
                      nameController.text.isNotEmpty) ...[
                    const Text(
                      'Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    TextField(
                      readOnly: widget.viewedProfile != null,
                      controller: nameController,
                      onChanged: (_) => _markAsChanged(),
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (widget.viewedProfile == null ||
                      personalDetailsController.text.isNotEmpty) ...[
                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    TextField(
                      readOnly: widget.viewedProfile != null,
                      controller: personalDetailsController,
                      onChanged: (_) => _markAsChanged(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Tell us a little about yourself',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (widget.viewedProfile == null ||
                      coursesController.text.isNotEmpty) ...[
                    const Text(
                      'Courses',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    TextField(
                      readOnly: widget.viewedProfile != null,
                      controller: coursesController,
                      onChanged: (_) => _markAsChanged(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. COMP602, COMP604',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (widget.viewedProfile == null ||
                      interestsController.text.isNotEmpty) ...[
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    TextField(
                      readOnly: widget.viewedProfile != null,
                      controller: interestsController,
                      onChanged: (_) => _markAsChanged(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Programming, AI, Cybersecurity',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (widget.viewedProfile == null ||
                      preferencesController.text.isNotEmpty) ...[
                    const Text(
                      'Preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    TextField(
                      readOnly: widget.viewedProfile != null,
                      controller: preferencesController,
                      onChanged: (_) => _markAsChanged(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Study preferences, group work, etc.',
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),

                  const Text(
                    'Languages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (widget.viewedProfile == null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableLanguages.map((language) {
                        return FilterChip(
                          label: Text(language),
                          selected: _selectedLanguages.contains(language),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLanguages.add(language);
                              } else {
                                _selectedLanguages.remove(language);
                              }
                              _hasChanges = true;
                            });
                          },
                        );
                      }).toList(),
                    )
                  else if (_selectedLanguages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _selectedLanguages.map((language) {
                        return Chip(label: Text(language));
                      }).toList(),
                    )
                  else
                    const Text(
                      'No languages added.',
                      style: TextStyle(color: Colors.grey),
                    ),

                  const SizedBox(height: 30),

                  if (widget.viewedProfile == null && _hasChanges)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Profile'),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
