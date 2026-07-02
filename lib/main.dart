import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PoemApp());
}

class PoemApp extends StatelessWidget {
  const PoemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '诸子百家 · Voice Poem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}