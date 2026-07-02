import 'package:flutter/material.dart';

import '../models/poem_result.dart';

class PoemScreen extends StatelessWidget {
  final PoemResult result;

  const PoemScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14151A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PersonaTag(name: result.personaName, english: result.personaEnglishName),
              const SizedBox(height: 28),
              Text(
                result.poem,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Divider(color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 20),
              Text(
                'You said',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.transcript,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Meaning',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.explanation,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaTag extends StatelessWidget {
  final String name;
  final String english;

  const _PersonaTag({required this.name, required this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CC3).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8E7CC3).withOpacity(0.4)),
      ),
      child: Text(
        '$name · $english',
        style: const TextStyle(
          color: Color(0xFFC9BFE8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}