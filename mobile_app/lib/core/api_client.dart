import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin JSON client that attaches the bearer token and turns every failure
/// into an [ApiException] with a message that is safe to show to the user.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;

  /// Called when the server rejects the saved session (expired/invalid token).
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      path: '${base.path}$path'.replaceAll('//', '/'),
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> _headers({required bool auth}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, bool auth = true}) =>
      _send(() => http.get(_uri(path, query), headers: _headers(auth: auth)),
          auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) => _send(
      () => http.post(_uri(path),
          headers: _headers(auth: auth), body: jsonEncode(body ?? {})),
      auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) => _send(
      () => http.patch(_uri(path),
          headers: _headers(auth: auth), body: jsonEncode(body ?? {})),
      auth);

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send(() => http.delete(_uri(path), headers: _headers(auth: auth)), auth);

  Future<dynamic> _send(
      Future<http.Response> Function() request, bool auth) async {
    final http.Response response;
    try {
      response = await request().timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException(
          'The server took too long to respond. Please try again.');
    } catch (_) {
      throw const ApiException(
          'Cannot reach the server. Check your connection and that the backend is running.');
    }

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401 && auth) {
      onUnauthorized?.call();
    }
    throw ApiException(_errorMessage(data, response.statusCode),
        response.statusCode);
  }

  String _errorMessage(dynamic data, int status) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((e) => e is Map ? (e['msg'] ?? e).toString() : e.toString())
            .join('\n');
      }
      return detail.toString();
    }
    if (status >= 500) return 'Server error. Please try again later.';
    return 'Request failed ($status).';
  }
}
