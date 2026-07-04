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

  bool _obscureApiKey = true;
  bool _justSaved = false;
  bool _apiKeyPresent = false;
  bool _isLoading = true;

  String _selectedModel = StorageService.defaultModel;
  double _temperature = StorageService.defaultTemperature;

  final List<Map<String, String>> _availableModels = [
    {'value': 'gemini-2.0-flash', 'label': '2.0 Flash (Fast & Fluid)'},
    {'value': 'gemini-2.0-flash-lite', 'label': '2.0 Flash Lite (Lightweight)'},
    {'value': 'gemini-1.5-flash', 'label': '1.5 Flash (Fast & Fluid)'},
    {'value': 'gemini-1.5-pro', 'label': '1.5 Pro (Deep & Insightful)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await _storage.getApiKey();
    final model = await _storage.getGeminiModel();
    final temp = await _storage.getGeminiTemperature();

    if (mounted) {
      setState(() {
        if (apiKey != null) _apiKeyController.text = apiKey;
        _apiKeyPresent = apiKey != null && apiKey.isNotEmpty;
        _selectedModel = model;
        _temperature = temp;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAll() async {
    final trimmedKey = _apiKeyController.text.trim();

    if (trimmedKey.isEmpty) {
      await _storage.clearApiKey();
    } else {
      await _storage.saveApiKey(trimmedKey);
    }

    await _storage.saveGeminiParams(
      model: _selectedModel,
      temperature: _temperature,
    );

    setState(() {
      _apiKeyPresent = trimmedKey.isNotEmpty;
      _justSaved = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _clearAll() async {
    await _storage.clearApiKey();
    await _storage.saveGeminiParams(
      model: StorageService.defaultModel,
      temperature: StorageService.defaultTemperature,
    );

    _apiKeyController.clear();

    setState(() {
      _apiKeyPresent = false;
      _selectedModel = StorageService.defaultModel;
      _temperature = StorageService.defaultTemperature;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final apiKeyStatusColor =
        _apiKeyPresent ? AppColors.jade : AppColors.crimson;

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
                    style: TextStyle(
                        color: AppColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusIndicator(apiKeyStatusColor),
                  const SizedBox(width: 6),
                  Text(
                    _apiKeyPresent ? 'Active' : 'Optional / Not set',
                    style: TextStyle(
                        color: apiKeyStatusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get a free key at aistudio.google.com. Stored locally.',
                style: TextStyle(
                    color: AppColors.paper.withOpacity(0.5), fontSize: 13),
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
                    icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.paper.withOpacity(0.5)),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ==========================================
              // FIELD 2: MODEL SELECTION
              // ==========================================
              const Text(
                'AI Model',
                style: TextStyle(
                    color: AppColors.paper,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the brain powering your writing mentor.',
                style: TextStyle(
                    color: AppColors.paper.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableModels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _availableModels[index];
                  final isSelected = _selectedModel == item['value'];
                  return InkWell(
                    onTap: () =>
                        setState(() => _selectedModel = item['value']!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold.withOpacity(0.08)
                            : AppColors.inkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.inkBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.paper.withOpacity(0.4),
                          ),
                          const SizedBox(width: 14),
                          Text(item['label']!,
                              style: TextStyle(
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.paper,
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ==========================================
              // FIELD 3: TEMPERATURE CONTROL
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Creativity Level',
                    style: TextStyle(
                        color: AppColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(_temperature.toStringAsFixed(1),
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Adjust how experimental the AI should be with its feedback.',
                style: TextStyle(
                    color: AppColors.paper.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.inkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inkBorder),
                ),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.gold,
                        inactiveTrackColor: AppColors.inkBorder,
                        thumbColor: AppColors.gold,
                        overlayColor: AppColors.gold.withOpacity(0.12),
                        valueIndicatorColor: AppColors.seal,
                      ),
                      child: Slider(
                        value: _temperature,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        onChanged: (val) => setState(() => _temperature = val),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Analytical',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          Text('Imaginative',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child:
                        Text(_justSaved ? 'Settings Saved ✨' : 'Save Settings'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _clearAll,
                    child: Text('Reset',
                        style:
                            TextStyle(color: AppColors.paper.withOpacity(0.6))),
                  ),
                ],
              ),
              const SizedBox(height: 40),
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
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.6),
              blurRadius: 6,
              spreadRadius: 1)
        ],
      ),
    );
  }

  // Component extraction for input decorators to keep widget layout highly legible
  InputDecoration _buildInputDecoration(
      {required String hintText,
      required Color statusColor,
      Widget? suffixIcon}) {
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
