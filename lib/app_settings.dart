import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _pingTimeoutKey = 'ping_timeout';
  static const String _httpTimeoutKey = 'http_timeout';

  // Valores padrão
  static const int _defaultPingTimeout = 500; // em milissegundos
  static const int _defaultHttpTimeout = 1000; // em milissegundos

  Future<void> setPingTimeout(int timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pingTimeoutKey, timeout);
  }

  Future<int> getPingTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pingTimeoutKey) ?? _defaultPingTimeout;
  }

  Future<void> setHttpTimeout(int timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_httpTimeoutKey, timeout);
  }

  Future<int> getHttpTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_httpTimeoutKey) ?? _defaultHttpTimeout;
  }
}
