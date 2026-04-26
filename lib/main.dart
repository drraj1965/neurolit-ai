import 'package:flutter/material.dart';

import 'services/app_version_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppVersionService.appName,
      home: const HomeScreen(),
    );
  }
}
