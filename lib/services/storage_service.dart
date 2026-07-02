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
    final prefs = await SharedPreferences.getInstance();
    final list = await getHistory();
    list.insert(0, entry); // newest first
    final jsonList = list.map((e) => e.toJson()).toList();
    await prefs.setString(_historyPref, jsonEncode(jsonList));
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
}