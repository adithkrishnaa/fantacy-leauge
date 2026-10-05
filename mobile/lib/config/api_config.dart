/// Backend endpoint configuration.
///
/// Defaults target the local Express server (`backend/server.js`, port 5001).
/// `10.0.2.2` is the Android emulator's alias for the host machine's
/// `localhost` — a physical device on the same Wi-Fi needs the host's LAN IP
/// instead. Override without editing this file:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:5001
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5001',
  );

  static String get apiRoot => '$baseUrl/api';
}
