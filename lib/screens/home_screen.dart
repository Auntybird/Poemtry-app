import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'speak_screen.dart';
import 'write_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -60,
              child: AmbientGlow(color: AppColors.seal, size: 260),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: AmbientGlow(color: AppColors.violet, size: 240),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(Icons.settings_rounded, color: AppColors.paper.withOpacity(0.6)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(child: SealBadge()),
                  const SizedBox(height: 20),
                  const Text(
                    '诗魂',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '问道九家 · 落笔成诗',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold.withOpacity(0.85),
                      fontSize: 13,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 44),
                  _ActionCard(
                    icon: Icons.mic_rounded,
                    title: '开口而言',
                    subtitle: 'Speak your mind, let a philosophy answer',
                    accent: AppColors.seal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SpeakScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActionCard(
                    icon: Icons.edit_note_rounded,
                    title: '落笔为诗',
                    subtitle: 'Write your own poem or thought, get guidance',
                    accent: AppColors.gold,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WriteScreen()),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          icon: Icons.history_rounded,
                          label: 'History',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HistoryScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PillButton(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: AppColors.paper, fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.paper.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.inkSurfaceLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.paper.withOpacity(0.75), size: 20),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: AppColors.paper.withOpacity(0.7), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}