import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';

class StorageService {
  static const _apiKeyPref = 'gemini_api_key';
  static const _historyPref = 'poem_history';

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

  Future<void> addHistoryEntry(HistoryEntry entry) async {
    final list = await getHistory();
    list.insert(0, entry);
    await _saveList(list);
  }

  Future<void> updateHistoryEntry(HistoryEntry updated) async {
    final list = await getHistory();
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
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
}