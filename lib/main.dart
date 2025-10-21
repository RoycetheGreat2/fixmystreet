import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
void main() {
  runApp(const FixMyStreetApp());
}

class FixMyStreetApp extends StatelessWidget {
  const FixMyStreetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FixMyStreet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
      routes: {
        '/signup': (context) => const SignUpPage(), // <- add this
      },
    );
  }
}
