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
  
  // Controllers
  final _apiKeyController = TextEditingController();
  final _secondaryController = TextEditingController(); // 💡 Customize this for your 2nd setting
  
  bool _obscureApiKey = true;
  bool _obscureSecondary = false; // Set to true if this should also be a hidden password/token
  
  bool _justSaved = false;
  bool _apiKeyPresent = false;
  bool _secondaryPresent = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await _storage.getApiKey();
    // 💡 Replace with your actual secondary storage getter method
    final secondaryConfig = await _storage.getSecondaryConfig(); 

    if (apiKey != null) _apiKeyController.text = apiKey;
    if (secondaryConfig != null) _secondaryController.text = secondaryConfig;

    setState(() {
      _apiKeyPresent = apiKey != null && apiKey.isNotEmpty;
      _secondaryPresent = secondaryConfig != null && secondaryConfig.isNotEmpty;
    });
  }

  Future<void> _saveAll() async {
    final trimmedKey = _apiKeyController.text.trim();
    final trimmedSecondary = _secondaryController.text.trim();

    // Save both optionally to storage
    await _storage.saveApiKey(trimmedKey);
    await _storage.saveSecondaryConfig(trimmedSecondary); // 💡 Replace with your method

    setState(() {
      _apiKeyPresent = trimmedKey.isNotEmpty;
      _secondaryPresent = trimmedSecondary.isNotEmpty;
      _justSaved = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _clearAll() async {
    await _storage.clearApiKey();
    await _storage.clearSecondaryConfig(); // 💡 Replace with your method
    
    _apiKeyController.clear();
    _secondaryController.clear();

    setState(() {
      _apiKeyPresent = false;
      _secondaryPresent = false;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyStatusColor = _apiKeyPresent ? AppColors.jade : AppColors.crimson;
    final secondaryStatusColor = _secondaryPresent ? AppColors.jade : AppColors.crimson;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('Settings')),
      // Wrapped in a scroll view so the viewport scales beautifully when the keyboard jumps up
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // FIELD 1: GEMINI API KEY
              // ==========================================
              Row(
                children: [
                  const Text(
                    'Gemini API Key',
                    style: TextStyle(color: AppColors.paper, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusIndicator(apiKeyStatusColor),
                  const SizedBox(width: 6),
                  Text(
                    _apiKeyPresent ? 'Active' : 'Optional / Not set',
                    style: TextStyle(color: apiKeyStatusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get a free key at aistudio.google.com. Stored locally.',
                style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                style: const TextStyle(color: AppColors.paper),
                decoration: _buildInputDecoration(
                  hintText: 'Paste your API key here', 
                  statusColor: apiKeyStatusColor,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility, color: AppColors.paper.withOpacity(0.5)),
                    onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),

              const SizedBox(height: 32), // Breathing room between settings blocks

              // ==========================================
              // FIELD 2: SECONDARY OPTIONAL SETTING
              // ==========================================
              Row(
                children: [
                  const Text(
                    'Secondary Configuration', // 💡 Rename to "Firebase URL", etc.
                    style: TextStyle(color: AppColors.paper, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusIndicator(secondaryStatusColor),
                  const SizedBox(width: 6),
                  Text(
                    _secondaryPresent ? 'Active' : 'Optional / Not set',
                    style: TextStyle(color: secondaryStatusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Provide your optional project backend reference string or alternative service URL.',
                style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secondaryController,
                obscureText: _obscureSecondary,
                style: const TextStyle(color: AppColors.paper),
                decoration: _buildInputDecoration(
                  hintText: 'Enter secondary target identifier', 
                  statusColor: secondaryStatusColor,
                ),
              ),

              const SizedBox(height: 40),

              // ==========================================
              // UNIFIED ACTION BUTTONS
              // ==========================================
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _saveAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.seal,
                      foregroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_justSaved ? 'Settings Saved ✓' : 'Save Settings'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _clearAll,
                    child: Text('Clear All', style: TextStyle(color: AppColors.paper.withOpacity(0.6))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Visual helper to build matching neon glow indicator dots
  Widget _buildStatusIndicator(Color statusColor) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: statusColor,
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
      ),
    );
  }

  // Component extraction for input decorators to keep widget layout highly legible
  InputDecoration _buildInputDecoration({required String hintText, required Color statusColor, Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.inkSurface,
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.paper.withOpacity(0.3)),
      suffixIcon: suffixIcon,
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
    );
  }
}