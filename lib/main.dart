import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'PingFang SC',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}