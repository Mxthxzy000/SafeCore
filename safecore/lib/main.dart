import 'package:flutter/material.dart';
import 'pages/login.dart'; // Update the import to point to the correct LoginPage

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home:
          LoginPage(), // This will now reference the LoginPage from login.dart
    );
  }
}
