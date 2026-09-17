import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../Schedule/schedule.page.dart';
import '../Settings/settings.page.dart';
// import matchmaking, communication, profile, and settings pages when implemented

class AppBottomNavigationBar extends StatefulWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.refreshToken,
  });

  final String apiBaseUrl;
  final String accessToken;
  final String refreshToken;

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  final _storage = FlutterSecureStorage();

  int currentIndex = 0;
  late String _accessToken;
  late String _refreshToken;

  @override
  void initState() {
    super.initState();

    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: _buildPage(currentIndex),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                // Clear frosted glass
                color: Colors.white.withValues(alpha: 0.45),

                borderRadius: BorderRadius.circular(30),

                // Soft shadow
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 325,
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.calendar_month,
                        label: 'Schedule',
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.people,
                        label: 'Match',
                      ),
                      _buildNavItem(index: 2, icon: Icons.chat, label: 'Chat'),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.person,
                        label: 'Profile',
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.settings,
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (index == 0) {
            await _loadStoredTokens();
          }

          if (!mounted) return;

          setState(() {
            currentIndex = index;
          });
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 65,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 22),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadStoredTokens() async {
    final accessToken = await _storage.read(key: 'access_token');
    final refreshToken = await _storage.read(key: 'refresh_token');

    if (accessToken == null || refreshToken == null) return;

    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return SchedulerScreen(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
        );
      case 1:
        return const Center(child: Text('Matchmaking Page'));
      case 2:
        return const Center(child: Text('Communication Page'));
      case 3:
        return const Center(child: Text('Profile Page'));
      case 4:
        return SettingsPage(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
        );
      default:
        return const Center(child: Text('Page not found'));
    }
  }
}
