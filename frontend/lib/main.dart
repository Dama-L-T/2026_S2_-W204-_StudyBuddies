import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/auth/auth_gate.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://czbbccdenyxalojpvhfa.supabase.co',
    publishableKey: 'sb_publishable_7ZAyd6WFurqeczH2iKXHAQ_d6Snl_vf',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AuthGate(),
    );
  }
}