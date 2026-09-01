import 'package:flutter/material.dart';

import 'Schedule/schedule.page.dart';

void main() {
  runApp(const StudyBuddiesApp());
}

class StudyBuddiesApp extends StatelessWidget {
  const StudyBuddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Buddies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SchedulerScreen(),
    );
  }
}
