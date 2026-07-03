import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PoeticPromptBanner extends StatelessWidget {
  final String promptText;
  final String personaName;
  final bool isLoading;

  const PoeticPromptBanner({
    super.key,
    required this.promptText,
    required this.personaName,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(promptText),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, size: 14, color: AppColors.gold.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text(
                  "$personaName's Daily Inspiration",
                  style: TextStyle(
                    color: AppColors.gold.withOpacity(0.8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isLoading) ...[
                  const Spacer(),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
                  )
                ]
              ],
            ),
            const SizedBox(height: 8),
            Text(
              promptText,
              style: TextStyle(
                color: AppColors.paper.withOpacity(0.85),
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}