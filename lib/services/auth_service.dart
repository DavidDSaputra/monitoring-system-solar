import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../config/api_base_urls.dart';
import '../config/app_constants.dart';

class AuthService {
  AuthService._();

  static const _usernameKey = 'solarview.biometric.username';
  static const _passwordKey = 'solarview.biometric.password';
  static const _biometricEnabledKey = 'solarview.biometric.enabled';
  static const _biometricReason =
      'Gunakan fingerprint atau Face ID untuk masuk ke SolarView';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static bool _loggedIn = false;
  static bool get isLoggedIn => _loggedIn;

  static Future<bool> login(
    String username,
    String password, {
    bool rememberForBiometrics = true,
  }) async {
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
          if (rememberForBiometrics) {
            await _rememberCredentials(username.trim(), password);
          }
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

  static Future<bool> isBiometricLoginAvailable() async {
    try {
      final enabled =
          await _secureStorage.read(key: _biometricEnabledKey) == 'true';
      if (!enabled) return false;

      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      if (username == null || username.isEmpty || password == null) {
        return false;
      }

      return await _hasEnrolledBiometrics();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> loginWithBiometrics() async {
    if (!await isBiometricLoginAvailable()) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: _biometricReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) return false;

      final username = await _secureStorage.read(key: _usernameKey);
      final password = await _secureStorage.read(key: _passwordKey);
      if (username == null || password == null) return false;

      return await login(
        username,
        password,
        rememberForBiometrics: false,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasEnrolledBiometrics() async {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) return false;
    final available = await _localAuth.getAvailableBiometrics();
    return available.isNotEmpty;
  }

  static Future<void> _rememberCredentials(
    String username,
    String password,
  ) async {
    try {
      await _secureStorage.write(key: _usernameKey, value: username);
      await _secureStorage.write(key: _passwordKey, value: password);
      if (await _hasEnrolledBiometrics()) {
        await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      }
    } catch (_) {
      // Password login must still succeed when the device has no secure
      // storage or biometric hardware.
    }
  }

  static void logout() => _loggedIn = false;

  static Future<void> disableBiometricLogin() async {
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _biometricEnabledKey);
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() {
    return message;
  }
}
