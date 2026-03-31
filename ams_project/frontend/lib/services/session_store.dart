import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class StoredSession {
  const StoredSession({required this.token, required this.user});

  final String token;
  final SessionUser user;
}

abstract class SessionStore {
  Future<StoredSession?> read();

  Future<void> save({required String token, required SessionUser user});

  Future<void> clear();
}

class SharedPreferencesSessionStore implements SessionStore {
  static const _tokenKey = 'ams.token';
  static const _userKey = 'ams.user';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<StoredSession?> read() async {
    final prefs = await _prefs;
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (token == null || userJson == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(userJson) as Map<String, dynamic>;
      return StoredSession(token: token, user: SessionUser.fromJson(decoded));
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save({required String token, required SessionUser user}) async {
    final prefs = await _prefs;
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
