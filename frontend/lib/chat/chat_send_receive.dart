
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthExpiredException implements Exception {
  final String message;

  AuthExpiredException([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  String toString() => message;
}

class ChatApiClient {
  final String apiBaseUrl;
  final FlutterSecureStorage storage;

  String? _accessToken;
  String? _fallbackRefreshToken;
  Future<bool>? _refreshFuture;

  ChatApiClient({
    required this.apiBaseUrl,
    required String? accessToken,
    required String? refreshToken,
    required this.storage,
  })  : _accessToken = accessToken,
        _fallbackRefreshToken = refreshToken;

  Future<List<Map<String, dynamic>>> getConversations() async {
    final result = await _request('GET', '/chat/conversations');

    return _extractList(result, [
      'conversations',
      'items',
      'data',
    ]);
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId,
  ) async {
    final result = await _request(
      'GET',
      '/chat/conversations/$conversationId/messages',
    );

    return _extractList(result, [
      'messages',
      'items',
      'data',
    ]);
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content,
  ) async {
    final result = await _request(
      'POST',
      '/chat/conversations/$conversationId/messages',
      body: {'content': content},
    );

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return {};
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String content,
  ) async {
    await _request(
      'PATCH',
      '/chat/conversations/$conversationId/messages/$messageId',
      body: {'content': content},
    );
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    await _request(
      'DELETE',
      '/chat/conversations/$conversationId/messages/$messageId',
    );
  }

  Future<void> reportMessage(
    String conversationId,
    String messageId,
    String reason,
  ) async {
    await _request(
      'POST',
      '/chat/conversations/$conversationId/messages/$messageId/report',
      body: {'reason': reason},
    );
  }

  Future<void> unreportMessage(
    String conversationId,
    String messageId,
  ) async {
    await _request(
      'DELETE',
      '/chat/conversations/$conversationId/messages/$messageId/report',
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    await _request(
      'POST',
      '/chat/conversations/$conversationId/read',
    );
  }
  
  Future<Map<String, dynamic>> getBlockStatus(
    String conversationId,
  ) async {
    final result = await _request(
      'GET',
      '/chat/conversations/$conversationId/block-status',
    );

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return {};
  }

  Future<void> blockUser(String conversationId) async {
    await _request(
      'POST',
      '/chat/conversations/$conversationId/block',
    );
  }

  Future<void> unblockUser(String conversationId) async {
    await _request(
      'DELETE',
      '/chat/conversations/$conversationId/block',
    );
  }

  Future<void> unblockUserById(String blockedUserId) async {
    await _request(
      'DELETE',
      '/chat/blocked-users/$blockedUserId',
    );
  }

  Future<void> hideConversation(String conversationId) async {
    await _request(
      'POST',
      '/chat/conversations/$conversationId/hide',
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) async {
    _accessToken ??= await storage.read(key: 'access_token');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };

    final uri = Uri.parse('$apiBaseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: encodedBody,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: encodedBody,
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: headers,
        );
        break;
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }

    if (response.statusCode == 401 && retryAfterRefresh) {
      final refreshed = await _refreshSession();

      if (!refreshed) {
        throw AuthExpiredException();
      }

      return _request(
        method,
        path,
        body: body,
        retryAfterRefresh: false,
      );
    }

    if (response.statusCode == 401) {
      throw AuthExpiredException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }

    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw Exception('The server returned an invalid response.');
    }
  }

  Future<bool> _refreshSession() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = _performRefresh();
    _refreshFuture = future;

    try {
      return await future;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _performRefresh() async {
    try {
      final token = await storage.read(key: 'refresh_token') ??
          _fallbackRefreshToken;

      if (token == null || token.isEmpty) {
        await _clearTokens();
        return false;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': token}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _clearTokens();
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        await _clearTokens();
        return false;
      }

      final data = Map<String, dynamic>.from(decoded);
      final newAccessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _clearTokens();
        return false;
      }

      _accessToken = newAccessToken;
      await storage.write(
        key: 'access_token',
        value: newAccessToken,
      );

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        _fallbackRefreshToken = newRefreshToken;
        await storage.write(
          key: 'refresh_token',
          value: newRefreshToken,
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _fallbackRefreshToken = null;

    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }

  List<Map<String, dynamic>> _extractList(
    dynamic result,
    List<String> possibleKeys,
  ) {
    dynamic value = result;

    if (value is Map) {
      for (final key in possibleKeys) {
        if (value[key] is List) {
          value = value[key];
          break;
        }
      }
    }

    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        final detail = decoded['detail'] ?? decoded['message'];

        if (detail != null) {
          return detail.toString();
        }
      }
    } catch (_) {
      // Fall back to the HTTP status code.
    }

    return 'Request failed (${response.statusCode}).';
  }

  Future<Map<String, dynamic>> getLoginOtpSetting() async {
    final result = await _request('GET', '/auth/login-otp-setting');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateLoginOtpSetting(
    bool enabled,
  ) async {
    final result = await _request(
      'PUT',
      '/auth/login-otp-setting',
      body: {'enabled': enabled},
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<dynamic> getBlockedUsers() {
    return _request('GET', '/chat/blocked-users');
  }

  Future<dynamic> getHiddenConversations() {
    return _request('GET', '/chat/hidden-conversations');
  }

  Future<void> restoreHiddenConversation(String conversationId) async {
    await _request(
      'DELETE',
      '/chat/conversations/$conversationId/hide',
    );
  }

  Future<void> sendPresenceHeartbeat() async {
    await _request('POST', '/chat/presence/heartbeat');
  }
}