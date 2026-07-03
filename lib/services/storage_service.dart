import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';
import '../models/writing_draft.dart';

class StorageService {
  static const _apiKeyPref = 'gemini_api_key';
  static const _historyPref = 'poem_history';
  static const _draftsPref = 'writing_drafts_list'; // 💡 Changed to list key
  
  // 💡 NEW: Gemini Configuration Keys
  static const _modelPref = 'gemini_model';
  static const _temperaturePref = 'gemini_temperature';

  // Default values
  static const String defaultModel = 'gemini-1.5-flash';
  static const double defaultTemperature = 0.7;

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

  // --- History (Completed Items) ---

  Future<void> addHistoryEntry(HistoryEntry entry) async {
    final list = await getHistory();
    list.insert(0, entry);
    await _saveList(list);
  }

  // 💡 NEW METHOD: Allows updating an already existing history item anytime
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

  Future<void> _saveList(List<HistoryEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // --- Multiple Notebook Drafts Management ---

  // 💡 Fetches all saved active drafts sorted by latest updated
  Future<List<WritingDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftsPref);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    final drafts = decoded.map((e) => WritingDraft.fromJson(e as Map<String, dynamic>)).toList();
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  // 💡 Saves or Updates a draft within the collection
  Future<void> saveDraft(WritingDraft draft) async {
    final list = await getDrafts();
    final idx = list.indexWhere((d) => d.id == draft.id);
    if (idx != -1) {
      list[idx] = draft;
    } else {
      list.insert(0, draft);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftsPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // 💡 Removes a single specific draft
  Future<void> deleteDraft(String id) async {
    final list = await getDrafts();
    list.removeWhere((d) => d.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftsPref, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}