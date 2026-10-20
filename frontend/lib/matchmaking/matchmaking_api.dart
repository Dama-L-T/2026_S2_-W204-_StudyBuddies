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

class BlockedStudent {
  BlockedStudent.fromJson(Map<String, dynamic> json)
    : blockedId = json['blocked_id'] as String,
      profile = StudentProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      );

  final String blockedId;
  final StudentProfile profile;
}

class StudyInvitation {
  StudyInvitation.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      profile = StudentProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      );
  final String id;
  final StudentProfile profile;
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
  Future<List<StudyInvitation>> incomingInvitations() async => [
    for (final item in await request('GET', '/matchmaking/invitations') as List)
      StudyInvitation.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  Future<Map<String, dynamic>> acceptedInvitations() async =>
      Map<String, dynamic>.from(
        await request('GET', '/matchmaking/invitations/accepted') as Map,
      );

  Future<List<String>> pendingInvitationIds() async {
    final response =
        await request('GET', '/matchmaking/invitations/count') as Map;
    return List<String>.from(response['ids'] as List);
  }

  Future<Map<String, String>> invitationStatuses() async =>
      Map<String, String>.from(
        await request('GET', '/matchmaking/invitations/statuses') as Map,
      );

  Future<int> invitationCount() async {
    final response =
        await request('GET', '/matchmaking/invitations/count') as Map;
    return response['count'] as int;
  }

  Future<void> respondToInvitation(String id, bool accept) async {
    await request(
      'PATCH',
      '/matchmaking/invitations/${Uri.encodeComponent(id)}',
      {'status': accept ? 'accepted' : 'declined'},
    );
  }

  Future<String> sendInvitation(String id) async {
    final response =
        await request(
              'POST',
              '/matchmaking/invitations/${Uri.encodeComponent(id)}',
            )
            as Map;
    return response['message'] as String;
  }

  Future<List<StudentProfile>> matchedPartners() async => [
    for (final item in await request('GET', '/matchmaking/partners') as List)
      StudentProfile.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  Future<void> restoreDismissed() async =>
      request('DELETE', '/matchmaking/dismissals');

  Future<List<StudentProfile>> savedProfiles(String status) async => [
    for (final item
        in await request('GET', '/matchmaking/choices?status=$status') as List)
      StudentProfile.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  Future<void> restoreProfile(String id) async =>
      request('DELETE', '/matchmaking/dismissals/${Uri.encodeComponent(id)}');

  Future<void> removeInterest(String id) async =>
      request('DELETE', '/matchmaking/interests/${Uri.encodeComponent(id)}');

  Future<String> blockStudent(String studentId) async {
    final response = await request(
      'POST',
      '/blocks/${Uri.encodeComponent(studentId)}',
    ) as Map;
    return response['message'] as String;
  }

  Future<List<BlockedStudent>> getBlockedStudents() async => [
    for (final item in await request('GET', '/blocks') as List)
      BlockedStudent.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  Future<String> unblockStudent(String studentId) async {
    final response = await request(
      'DELETE',
      '/blocks/${Uri.encodeComponent(studentId)}',
    ) as Map;
    return response['message'] as String;
  }

  void close() => _client.close();
}
