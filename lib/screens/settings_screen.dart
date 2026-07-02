import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _justSaved = false;
  bool _keyPresent = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _storage.getApiKey();
    if (key != null) _controller.text = key;
    setState(() => _keyPresent = key != null && key.isNotEmpty);
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    await _storage.saveApiKey(trimmed);
    setState(() {
      _keyPresent = trimmed.isNotEmpty;
      _justSaved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _clear() async {
    await _storage.clearApiKey();
    _controller.clear();
    setState(() => _keyPresent = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _keyPresent ? AppColors.jade : AppColors.crimson;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Gemini API Key',
                  style: TextStyle(color: AppColors.paper, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _keyPresent ? 'Active' : 'Not set',
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get a free key at aistudio.google.com. Stored only on this device.',
              style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.paper),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inkSurface,
                hintText: 'Paste your API key here',
                hintStyle: TextStyle(color: AppColors.paper.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: statusColor.withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: statusColor.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: statusColor, width: 1.4),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.paper.withOpacity(0.5)),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.seal,
                    foregroundColor: AppColors.paper,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_justSaved ? 'Saved ✓' : 'Save Key'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _clear,
                  child: Text('Clear', style: TextStyle(color: AppColors.paper.withOpacity(0.6))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}