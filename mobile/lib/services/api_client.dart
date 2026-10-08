import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/local_backend.dart';
import '../config/api_config.dart';

/// Thrown for any non-2xx response, carrying the backend's message.
///
/// `errorMiddleware.js` replies with `{ message: "..." }`, so we surface that
/// text directly rather than a generic HTTP error.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Single Dio instance shared by every service.
///
/// Attaches the JWT as `Authorization: Bearer <token>` — matching what
/// `authMiddleware.protect` expects — and normalises errors into
/// [ApiException].
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiRoot,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  static const String _tokenKey = 'auth_token';

  late final Dio _dio;
  String? _token;

  String? get token => _token;

  /// Restores the token persisted by a previous session, if any.
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      ApiConfig.embedded
          ? _local('GET', path)
          : _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) => ApiConfig.embedded
      ? _local('POST', path, body)
      : _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) => ApiConfig.embedded
      ? _local('PUT', path, body)
      : _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path) => ApiConfig.embedded
      ? _local('DELETE', path)
      : _send(() => _dio.delete(path));

  /// Embedded mode: run the request against the in-app backend.
  Future<dynamic> _local(String method, String path, [Object? body]) =>
      LocalBackend.instance.handle(method, path, body: body, token: _token);

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw ApiException(_messageFrom(e), statusCode: e.response?.statusCode);
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server at ${ApiConfig.baseUrl}. '
            'Check that the backend is running.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}
