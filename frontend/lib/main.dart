import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth/login_screen.dart';
import 'widgets/bottom_navigation_bar.dart';
import 'service/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await notificationService.initialise();
  final launchPayload = await notificationService.getLaunchPayload();

  final storage = FlutterSecureStorage();

  final accessToken = await storage.read(key: 'access_token');
  final refreshToken = await storage.read(key: 'refresh_token');

  runApp(
    MyApp(
      accessToken: accessToken,
      refreshToken: refreshToken,
      initialNotificationPayload: launchPayload,
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? accessToken;
  final String? refreshToken;
  final String? initialNotificationPayload;

  const MyApp({
    super.key,
    this.accessToken,
    this.refreshToken,
    this.initialNotificationPayload,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['API_BASE_URL']!;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Buddies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: accessToken != null && refreshToken != null
          ? AppBottomNavigationBar(
              apiBaseUrl: baseUrl,
              accessToken: accessToken!,
              refreshToken: refreshToken!,
              initialNotificationPayload: initialNotificationPayload,
            )
          : const LoginScreen(),
    );
  }
}
