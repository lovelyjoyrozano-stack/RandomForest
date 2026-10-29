import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Holds the signed-in user and persists the login between app launches.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  User? user;

  bool get isSignedIn => user != null && ApiClient.instance.token != null;

  Future<void> signIn(String token, User signedInUser) async {
    ApiClient.instance.token = token;
    user = signedInUser;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(signedInUser.toJson()));
    } catch (_) {
      // Storage unavailable: the session still works until the app closes.
    }
    notifyListeners();
  }

  /// Load a saved session and check it is still valid with the server.
  /// Returns false when there is none or it has expired.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final raw = prefs.getString(_userKey);
      if (token == null || raw == null) return false;

      ApiClient.instance.token = token;
      user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }

    try {
      final me = await ApiClient.instance.get('/me');
      user = User.fromJson(Map<String, dynamic>.from(me as Map));
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
        return false;
      }
      // Offline or server down: keep the saved session; screens show their own errors.
      return true;
    }
  }

  Future<void> signOut() async {
    ApiClient.instance.token = null;
    user = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
    notifyListeners();
  }
}
