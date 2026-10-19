import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/matchmaking/matchmaking.page.dart';
import 'package:frontend/matchmaking/matchmaking_api.dart';

void main() {
  for (final status in ['interested', 'uninterested']) {
    final title = status == 'interested' ? 'Interested' : 'Uninterested';
    final opposite = status == 'interested' ? 'uninterested' : 'interested';
    testWidgets(
      '$title X requires confirmation, preserves other choices, and restores eligibility',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profiles = {
          'alex': {'user_id': 'alex', 'name': 'Alex', 'interests': 'AI'},
          'sam': {'user_id': 'sam', 'name': 'Sam', 'interests': 'AI'},
        };
        final choices = {'alex': status, 'sam': opposite};
        var removals = 0;
        final api = MatchmakingApi(
          'https://example.test',
          'token',
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer token');
            if (request.url.path == '/profile/') {
              return http.Response('{"interests":"AI"}', 200);
            }
            if (request.url.path == '/matchmaking/choices') {
              return http.Response(
                jsonEncode([
                  for (final entry in choices.entries)
                    if (entry.value == request.url.queryParameters['status'])
                      profiles[entry.key],
                ]),
                200,
              );
            }
            if (request.url.path.contains('/profiles/')) {
              return http.Response(
                jsonEncode({
                  ...profiles['alex']!,
                  'personal_details': 'More detail',
                }),
                200,
              );
            }
            if (request.method == 'DELETE') {
              expect(
                request.url.path,
                status == 'interested'
                    ? '/matchmaking/interests/alex'
                    : '/matchmaking/dismissals/alex',
              );
              removals++;
              choices.remove('alex');
              return http.Response('', 204);
            }
            return http.Response(
              jsonEncode([
                for (final p in profiles.values)
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
        await tester.tap(find.byKey(Key('$status-list')));
        await tester.pumpAndSettle();
        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Sam'), findsNothing);
        if (status == 'interested') {
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Send invite'),
                )
                .onPressed,
            isNull,
          );
        } else {
          expect(find.text('Send invite'), findsNothing);
        }
        expect(find.text('Move to Uninterested'), findsNothing);
        await tester.tap(find.text('View profile'));
        await tester.pumpAndSettle();
        expect(find.text('Student Profile'), findsOneWidget);
        expect(find.text('Save Profile'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('remove-alex')));
        await tester.pumpAndSettle();
        expect(find.text('Remove this student from $title?'), findsOneWidget);
        expect(find.text('Are you sure?'), findsOneWidget);
        expect(
          find.text('They will appear again in your recommendations.'),
          findsOneWidget,
        );
        expect(removals, 0);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(removals, 0);
        expect(choices['alex'], status);
        expect(find.text('Alex'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('remove-alex')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(removals, 1);
        expect(find.text('Alex'), findsNothing);
        expect(choices, {'sam': opposite});
        expect(find.text('No $status students saved.'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('$status-list')));
        await tester.pumpAndSettle();
        expect(find.text('Alex'), findsNothing);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('find-buddies')));
        await tester.pumpAndSettle();
        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Sam'), findsNothing);
      },
    );

    testWidgets(
      '$title load and confirmed removal failures retain the entry for retry',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var loads = 0;
        var removals = 0;
        final api = MatchmakingApi(
          'https://example.test',
          'token',
          client: MockClient((request) async {
            if (request.url.path == '/profile/') {
              return http.Response('{"interests":"AI"}', 200);
            }
            if (request.method == 'DELETE') {
              removals++;
              return http.Response('{"detail":"Removal failed"}', 503);
            }
            if (loads++ == 0) {
              return http.Response('{"detail":"List unavailable"}', 503);
            }
            return http.Response(
              '[{"user_id":"alex","name":"Alex","interests":"AI"}]',
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
        await tester.tap(find.byKey(Key('$status-list')));
        await tester.pumpAndSettle();
        expect(find.text('List unavailable'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        for (var attempt = 1; attempt <= 2; attempt++) {
          await tester.tap(find.byKey(const ValueKey('remove-alex')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove'));
          await tester.pumpAndSettle();
          expect(removals, attempt);
          expect(find.text('Alex'), findsOneWidget);
          expect(find.text('Removal failed'), findsOneWidget);
        }
      },
    );

    testWidgets('$title empty list has a clear message', (tester) async {
      final api = MatchmakingApi(
        'https://example.test',
        'token',
        client: MockClient((request) async {
          return http.Response(
            request.url.path == '/profile/' ? '{"interests":"AI"}' : '[]',
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
      await tester.tap(find.byKey(Key('$status-list')));
      await tester.pumpAndSettle();
      expect(find.text('No $status students saved.'), findsOneWidget);
    });
  }
}
