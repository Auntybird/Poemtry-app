import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';
import '../models/writing_draft.dart';

class StorageService {
  static const _apiKeyPref = 'gemini_api_key';
  static const _historyPref = 'poem_history';
  static const _draftsPref = 'writing_drafts_list';

  static const _modelPref = 'gemini_model';
  static const _temperaturePref = 'gemini_temperature';
  static const _useAiVoicePref = 'use_ai_voice';
  static const _aiVoiceNamePref = 'ai_voice_name';

  // 🌟 Default is now 2.0-flash-lite for better daily inspiration limits
  static const String defaultModel = 'gemini-2.5-flash-lite';
  static const double defaultTemperature = 0.7;
  static const bool defaultUseAiVoice = false;
  static const String defaultAiVoiceName = 'Kore';

  // --- Gemini API Key ---

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }

  // --- Gemini Parameters Configuration ---

  Future<void> saveGeminiParams({required String model, required double temperature}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, model);
    await prefs.setDouble(_temperaturePref, temperature);
  }

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPref) ?? defaultModel;
  }

  Future<double> getGeminiTemperature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_temperaturePref) ?? defaultTemperature;
  }

  // --- AI Voice (Gemini TTS) Preference ---
  // Off by default — the app always works with the guaranteed-free
  // on-device voice; this is an opt-in enhancement that depends on
  // Gemini's TTS free tier remaining available.

  Future<void> saveAiVoicePrefs({required bool useAiVoice, required String voiceName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useAiVoicePref, useAiVoice);
    await prefs.setString(_aiVoiceNamePref, voiceName);
  }

  Future<bool> getUseAiVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useAiVoicePref) ?? defaultUseAiVoice;
  }

  Future<String> getAiVoiceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiVoiceNamePref) ?? defaultAiVoiceName;
  }

  // --- Daily Prompts Cache ---

  Future<List<String>?> getCachedWeeklyPrompts(String personaName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'prompts_cache_$personaName';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr == null) return null;

    try {
      final Map<String, dynamic> cache = jsonDecode(cachedDataStr);
      final DateTime fetchedAt = DateTime.parse(cache['fetchedAt']);

      if (DateTime.now().difference(fetchedAt).inDays >= 7) {
        return null;
      }

      final List<dynamic> prompts = cache['prompts'];
      if (prompts.isEmpty) return null;

      return prompts.cast<String>();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getDailyPrompt(String personaName) async {
    final prompts = await getCachedWeeklyPrompts(personaName);
    if (prompts == null || prompts.isEmpty) return null;

    int dayIndex = (DateTime.now().weekday - 1) % prompts.length;
    return prompts[dayIndex];
  }

  Future<void> saveWeeklyPrompts(String personaName, List<String> prompts) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'prompts_cache_$personaName';

    final cacheData = {
      'fetchedAt': DateTime.now().toIso8601String(),
      'prompts': prompts,
    };

    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  // --- History (Completed Items) ---

  Future<void> addHistoryEntry(HistoryEntry entry) async {
    final list = await getHistory();
    list.insert(0, entry);
    await _saveList(list);
  }

  Future<void> updateHistoryEntry(HistoryEntry entry) async {
    final list = await getHistory();
    final idx = list.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      list[idx] = entry;
      await _saveList(list);
    }
  }

  Future<void> toggleFavorite(String id) async {
    final list = await getHistory();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isFavorite: !list[idx].isFavorite);
      await _saveList(list);
    }
  }

  Future<void> deleteHistoryEntry(String id) async {
    final list = await getHistory();
    list.removeWhere((e) => e.id == id);
    await _saveList(list);
  }

  Future<List<HistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyPref);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyPref);
  }

  /// One-time (but safe-to-repeat) migration: any history entry saved before
  /// the Shan Shui art feature existed — or from when it silently failed —
  /// has imageUrl == null. This backfills a deterministic local art seed for
  /// those entries, same as new entries get. Idempotent: entries that
  /// already have an imageUrl are left untouched, so this can be called on
  /// every app/history load without doing repeated work or overwriting
  /// anything.
  Future<void> backfillMissingShanshuiArt() async {
    final list = await getHistory();
    var changed = false;

    for (var i = 0; i < list.length; i++) {
      if (list[i].imageUrl == null || list[i].imageUrl!.isEmpty) {
        final seed = list[i].poem.hashCode;
        list[i] = list[i].copyWith(imageUrl: 'local-art:$seed');
        changed = true;
      }
    }

    if (changed) {
      await _saveList(list);
    }
  }

  Future<void> _saveList(List<HistoryEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _historyPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // --- Multiple Notebook Drafts Management ---

  Future<List<WritingDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftsPref);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    final drafts = decoded
        .map((e) => WritingDraft.fromJson(e as Map<String, dynamic>))
        .toList();
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<void> saveDraft(WritingDraft draft) async {
    final list = await getDrafts();
    final idx = list.indexWhere((d) => d.id == draft.id);
    if (idx != -1) {
      list[idx] = draft;
    } else {
      list.insert(0, draft);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _draftsPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteDraft(String id) async {
    final list = await getDrafts();
    list.removeWhere((d) => d.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _draftsPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}