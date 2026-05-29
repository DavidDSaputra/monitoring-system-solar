class AuthService {
  AuthService._();

  static const String _validUsername = 'JARWINN';
  static const String _validPassword = 'jarwinn2026';

  static bool _loggedIn = false;
  static bool get isLoggedIn => _loggedIn;

  static bool login(String username, String password) {
    if (username.trim() == _validUsername &&
        password == _validPassword) {
      _loggedIn = true;
      return true;
    }
    return false;
  }

  static void logout() => _loggedIn = false;
}
