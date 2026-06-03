import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        handler.next(options);
      },
      onError: (DioException err, handler) async {
        if (err.response?.statusCode == 401) {
          // Token may have expired — refresh session and retry once
          try {
            await Supabase.instance.client.auth.refreshSession();
            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) {
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer ${session.accessToken}';
              final retry = await _dio.fetch(opts);
              handler.resolve(retry);
              return;
            }
          } catch (_) {}
        }
        handler.next(err);
      },
    ));
  }

  /// Converts a DioException into a short, readable message.
  static String _friendlyError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401) return 'Not authorised — please sign out and back in.';
      if (status == 403) return 'You don\'t have permission to do that.';
      if (status == 404) return 'Not found.';
      if (status == 429) return 'Too many requests — please wait a moment.';
      if (status != null && status >= 500) return 'Server error ($status) — try again shortly.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out — check your connection.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server — check your internet connection.';
      }
    }
    return e.toString();
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParams,
      );
      return response.data!;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response =
          await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data!;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response =
          await _dio.patch<Map<String, dynamic>>(path, data: body);
      return response.data!;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(path);
      return response.data!;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
