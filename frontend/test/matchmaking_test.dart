import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/matchmaking/matchmaking.page.dart';
import 'package:frontend/matchmaking/matchmaking_api.dart';

void main() {
  testWidgets(
    'session skips, persistent choices, profile view and request placeholder',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final choices = <String, String>{};
      final profiles = [
        {
          'user_id': 'alex',
          'name': 'Alex',
          'courses': 'COMP611',
          'interests': 'AI',
          'preferences': 'Evenings',
        },
        {'user_id': 'sam', 'name': 'Sam', 'interests': 'AI'},
        {'user_id': 'jordan', 'name': 'Jordan', 'interests': 'AI'},
      ];
      final api = MatchmakingApi(
        'https://example.test',
        'token',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.url.path == '/profile/') {
            return http.Response(
              '{"name":"Me","courses":"COMP611","interests":"AI"}',
              200,
            );
          }
          if (request.method == 'PUT') {
            choices[request.url.pathSegments.last] =
                (jsonDecode(request.body) as Map)['status'] as String;
            return http.Response('', 204);
          }
          if (request.url.path.contains('/profiles/')) {
            return http.Response(
              jsonEncode({
                ...profiles[0],
                'personal_details': 'Detailed profile',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode([
              for (final p in profiles)
                if (!choices.containsKey(p['user_id']))
                  {
                    'profile': p,
                    'shared_courses': [],
                    'shared_interests': ['AI'],
                  },
            ]),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MatchmakingPage(apiBaseUrl: '', accessToken: '', api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Interests'));
      await tester.tap(find.byKey(const Key('find-buddies')));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['criterion'], 'courses');
      expect(find.text('Evenings'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send request'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('View profile →'));
      await tester.pumpAndSettle();
      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.text('Save Profile'), findsNothing);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((f) => f.readOnly),
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Card), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(choices, isEmpty);
      expect(find.text('Sam'), findsOneWidget);
      await tester.drag(find.byType(Card), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(choices, {'sam': 'interested'});
      expect(find.text('Jordan'), findsOneWidget);
      await tester.tap(find.text('Uninterested'));
      await tester.pumpAndSettle();
      expect(choices, {'sam': 'interested', 'jordan': 'uninterested'});
      await tester.tap(find.byKey(const Key('exit-swiping')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('find-buddies')));
      await tester.pumpAndSettle();
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sam'), findsNothing);
      expect(find.text('Jordan'), findsNothing);
    },
  );

  testWidgets('failed save keeps student available for retry', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MatchmakingApi(
      'https://example.test',
      'token',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response('{"detail":"Please try again"}', 503);
        }
        if (request.url.path == '/profile/') {
          return http.Response('{"interests":"AI"}', 200);
        }
        return http.Response(
          '[{"profile":{"user_id":"alex","name":"Alex"},"shared_courses":[],"shared_interests":["AI"]}]',
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchmakingPage(apiBaseUrl: '', accessToken: '', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-buddies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uninterested'));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Please try again'), findsOneWidget);
  });
}
