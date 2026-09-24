import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  final String apiBaseUrl;
  final String accessToken;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool loginOtpEnabled = false;
  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadLoginOtpSetting();
  }

  Future<void> _loadLoginOtpSetting() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBaseUrl}/auth/login-otp-setting',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          loginOtpEnabled = data['enabled'] == true;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });

        debugPrint(
          'Failed to load OTP setting: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint(
        'Failed to load OTP setting: $error',
      );
    }
  }

  Future<void> _updateLoginOtpSetting(bool value) async {
    if (isUpdating) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
          '${widget.apiBaseUrl}/auth/login-otp-setting',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'enabled': value,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          loginOtpEnabled = data['enabled'] == true;
          isUpdating = false;
        });
      } else {
        setState(() {
          isUpdating = false;
        });

        debugPrint(
          'Failed to update OTP setting: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isUpdating = false;
      });

      debugPrint(
        'Failed to update OTP setting: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: const AppBarWidget(
        title: 'Settings',
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Security',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),

                  title: const Text(
                    'Login verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: const Text(
                    'Require a verification code when logging in',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  value: loginOtpEnabled,

                  onChanged: isUpdating
                      ? null
                      : _updateLoginOtpSetting,
                ),
          ),
        ],
      ),
    );
  }
}