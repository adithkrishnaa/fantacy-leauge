/// Backend configuration.
///
/// The app runs in one of two modes, chosen at build time:
///
/// * **Embedded** — `DATABASE_URL` is set. The backend logic runs inside the
///   app (`lib/backend/`) and talks straight to Postgres; no server needed.
///   Build with `--dart-define-from-file=backend.env.json` (git-ignored).
///   The connection string is extractable from the APK, so never distribute
///   such a build.
///
/// * **HTTP** — `DATABASE_URL` is unset. Requests go to the Express server
///   (`backend/server.js`, port 5001). `10.0.2.2` is the Android emulator's
///   alias for the host machine's `localhost`; override with
///   `--dart-define=API_BASE_URL=http://192.168.1.5:5001`.
class ApiConfig {
  static const String databaseUrl = String.fromEnvironment('DATABASE_URL');

  static bool get embedded => databaseUrl.isNotEmpty;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5001',
  );

  static String get apiRoot => '$baseUrl/api';
}
