import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_base_urls.dart';
import '../config/app_constants.dart';

class AuthService {
  AuthService._();

  static bool _loggedIn = false;
  static bool get isLoggedIn => _loggedIn;

  static Future<bool> login(String username, String password) async {
    final body = jsonEncode({
      'username': username.trim(),
      'password': password,
    });

    Object? lastError;
    for (final baseUrl in prioritizeMonitoringBaseUrls(
      resolveMonitoringApiBaseUrls(),
    )) {
      try {
        final uri = Uri.parse('$baseUrl/${AppConstants.authLoginPath}');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(monitoringApiTimeoutFor(baseUrl));
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          lastError = 'Invalid auth response';
          continue;
        }

        final ok = response.statusCode == 200 && decoded['success'] == true;
        if (ok) {
          rememberMonitoringBaseUrl(baseUrl);
          _loggedIn = true;
          return true;
        }

        if (response.statusCode == 401) return false;
        lastError = decoded['message']?.toString() ?? response.statusCode;
      } catch (e) {
        lastError = e;
      }
    }

    throw AuthException('Backend login tidak bisa dihubungi: $lastError');
  }

  static void logout() => _loggedIn = false;
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() {
    return message;
  }
}
