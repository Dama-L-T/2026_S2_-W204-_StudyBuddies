import 'dart:convert';
import 'package:http/http.dart' as http;
import '../profile/student_profile.dart';

class Recommendation {
  Recommendation.fromJson(Map<String, dynamic> json)
    : profile = StudentProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      courses = List<String>.from(json['shared_courses'] as List),
      interests = List<String>.from(json['shared_interests'] as List);
  final StudentProfile profile;
  final List<String> courses;
  final List<String> interests;
}

class MatchmakingApi {
  MatchmakingApi(this.baseUrl, this.accessToken, {http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) {
        throw Exception('Your session has expired. Please sign in again.');
      }
      String message = 'Could not complete the request. Please try again.';
      try {
        final detail = (jsonDecode(response.body) as Map)['detail'];
        if (detail is String) message = detail;
      } catch (_) {
        /* A server error may not contain JSON. */
      }
      throw Exception(message);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<StudentProfile> ownProfile() async => StudentProfile.fromJson(
    Map<String, dynamic>.from(await request('GET', '/profile/') as Map),
  );
  Future<List<Recommendation>> find(String criterion) async => [
    for (final item
        in await request('GET', '/matchmaking?criterion=$criterion') as List)
      Recommendation.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
  Future<StudentProfile> profile(String id) async => StudentProfile.fromJson(
    Map<String, dynamic>.from(
      await request('GET', '/matchmaking/profiles/${Uri.encodeComponent(id)}')
          as Map,
    ),
  );
  Future<void> saveChoice(String id, String status) async => request(
    'PUT',
    '/matchmaking/choices/${Uri.encodeComponent(id)}',
    {'status': status},
  );
  void close() => _client.close();
}
