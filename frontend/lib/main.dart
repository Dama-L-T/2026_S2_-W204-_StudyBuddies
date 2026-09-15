import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth/login_screen.dart';
import 'widgets/bottom_navigation_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  const storage = FlutterSecureStorage();

  final accessToken = await storage.read(
    key: 'access_token',
  );

  runApp(
    MyApp(
      accessToken: accessToken,
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? accessToken;

  const MyApp({
    super.key,
    this.accessToken,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['API_BASE_URL']!;
    final token = accessToken;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Buddies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: token != null
          ? AppBottomNavigationBar(
              apiBaseUrl: baseUrl,
              accessToken: token,
            )
          : const LoginScreen(),
    );
  }
}