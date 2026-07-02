import 'package:flutter/material.dart';

import '../models/poem_result.dart';
import '../theme/app_theme.dart';

class PoemScreen extends StatelessWidget {
  final PoemResult result;

  const PoemScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(),
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
                  color: AppColors.paper,
                  fontSize: 22,
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              Container(height: 1, color: AppColors.inkBorder),
              const SizedBox(height: 20),
              Text('You said', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(
                result.transcript,
                style: TextStyle(color: AppColors.paper.withOpacity(0.75), fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
              ),
              const SizedBox(height: 28),
              Text('Meaning', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(result.explanation, style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.6)),
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
        color: AppColors.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Text('$name · $english', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}