import 'package:flutter/foundation.dart';

/// Backend URL. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
  // The Android emulator reaches the host machine at 10.0.2.2, not 127.0.0.1.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

const Duration requestTimeout = Duration(seconds: 20);
