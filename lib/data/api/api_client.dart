import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/data/models/models.dart';

/// Lỗi API đã dịch sang tiếng Việt thân thiện với người dùng.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Token được lưu trong FlutterSecureStorage (Android: Keystore/EncryptedSharedPreferences)
/// -> không đọc được nếu ai đó copy file dữ liệu app.
const kAccessKey = 'soulmate.access_token';
const kRefreshKey = 'soulmate.refresh_token';
const secureStorage = FlutterSecureStorage();

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      contentType: Headers.jsonContentType,
    ));
    // Lớp 401: tự làm mới access token (single-flight) rồi thử lại request gốc
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isRefreshCall = path.contains('/api/auth/refresh');
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (status == 401 && !isRefreshCall && !alreadyRetried) {
          final refreshed = await _refreshTokens();
          if (refreshed) {
            final opts = error.requestOptions;
            opts.extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer $_accessToken';
            try {
              final res = await _dio.fetch<dynamic>(opts);
              return handler.resolve(res);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          await clearSession();
          onSessionExpired?.call();
        }
        handler.next(error);
      },
    ));
  }

  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  Completer<bool>? _refreshing;

  /// Được auth repository gán: gọi khi phiên đăng nhập hết hạn thật sự.
  void Function()? onSessionExpired;

  /// Đổi địa chỉ máy chủ lúc runtime (sau AppConfig.applyServerHost).
  void applyServerHost() => _dio.options.baseUrl = AppConfig.apiBaseUrl;

  bool get hasSession => _accessToken != null || _refreshToken != null;

  Future<void> loadTokens() async {
    _accessToken = await secureStorage.read(key: kAccessKey);
    _refreshToken = await secureStorage.read(key: kRefreshKey);
  }

  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await secureStorage.write(key: kAccessKey, value: access);
    await secureStorage.write(key: kRefreshKey, value: refresh);
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await secureStorage.delete(key: kAccessKey);
    await secureStorage.delete(key: kRefreshKey);
  }

  Future<bool> _refreshTokens() async {
    if (_refreshToken == null) return false;
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;
    try {
      // Dùng Dio độc lập để không đi qua interceptor (tránh đệ quy)
      final plain = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10)));
      final res = await plain.post('/api/auth/refresh',
          data: {'refreshToken': _refreshToken});
      final data = res.data as Map<String, dynamic>;
      await _saveTokens(
          data['accessToken'] as String, data['refreshToken'] as String);
      completer.complete(true);
    } catch (_) {
      completer.complete(false);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  // ==================== AUTH ====================

  Future<({UserModel user, bool profileCompleted})> register(
      String email, String password, String name) async {
    final data = await _post('/api/auth/register',
        data: {'email': email, 'password': password, 'name': name});
    await _saveTokens(data['accessToken'], data['refreshToken']);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    return (user: user, profileCompleted: user.profileCompleted);
  }

  Future<({UserModel user, bool profileCompleted})> login(
      String email, String password) async {
    final data = await _post('/api/auth/login',
        data: {'email': email, 'password': password});
    await _saveTokens(data['accessToken'], data['refreshToken']);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    return (user: user, profileCompleted: user.profileCompleted);
  }

  Future<void> logoutOnServer() async {
    final refresh = _refreshToken;
    if (refresh == null) return;
    try {
      await _post('/api/auth/logout', data: {'refreshToken': refresh});
    } catch (_) {
      // vẫn thu hồi local bên dưới
    }
  }

  Future<({UserModel user, bool profileCompleted})> getMe() async {
    final data = await _get('/api/me');
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    return (user: user, profileCompleted: user.profileCompleted);
  }

  Future<UserModel> updateMe(Map<String, dynamic> body) async {
    final data = await _patch('/api/me', data: body);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Đổi mật khẩu -> server thu hồi phiên cũ và trả token mới (lưu ngay).
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final data = await _post('/api/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    await _saveTokens(
        data['accessToken'] as String, data['refreshToken'] as String);
  }

  /// Upload 1 file ảnh (bytes) -> trả về URL tương đối trên server.
  Future<String> uploadImage(List<int> bytes, {String mime = 'jpeg'}) async {
    final ext = mime == 'png' ? 'png' : (mime == 'webp' ? 'webp' : 'jpeg');
    final dataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
    final data = await _post('/api/upload', data: {'dataUrl': dataUrl});
    return data['url'] as String;
  }

  // ==================== HTTP helpers ====================

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> _post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> _patch(String path, {dynamic data}) async {
    try {
      final res = await _dio.patch(path, data: data);
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> _delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Public: cho các repository (chat/feed/room) gọi trực tiếp.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _get(path, query: query);
  Future<dynamic> post(String path, {dynamic data}) => _post(path, data: data);
  Future<dynamic> patch(String path, {dynamic data}) =>
      _patch(path, data: data);
  Future<dynamic> delete(String path) => _delete(path);

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return ApiException(data['message'] as String, statusCode: status);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Máy chủ phản hồi quá chậm — thử lại sau',
            statusCode: status);
      case DioExceptionType.connectionError:
        return ApiException('Không thể kết nối máy chủ — kiểm tra mạng hoặc USB',
            statusCode: status);
      default:
        break;
    }
    if (e.error is SocketException || e.error is HandshakeException) {
      return ApiException('Không thể kết nối máy chủ — kiểm tra mạng hoặc USB',
          statusCode: status);
    }
    if (status == 401) return ApiException('Phiên đăng nhập hết hạn', statusCode: 401);
    if (status == 429) return ApiException('Thao tác quá nhanh — thử lại sau ít phút', statusCode: 429);
    if (status == 423) return ApiException('Tài khoản tạm khóa do nhập sai nhiều lần', statusCode: 423);
    if (status != null && status >= 500) {
      return ApiException('Máy chủ gặp sự cố — thử lại sau', statusCode: status);
    }
    return ApiException('Đã có lỗi xảy ra', statusCode: status);
  }
}
