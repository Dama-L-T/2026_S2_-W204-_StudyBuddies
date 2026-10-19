import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/auth/login_screen.dart';

void main() {
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    dotenv.testLoad( fileInput: 'API_BASE_URL=http://127.0.0.1:8000');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Future<void> openLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder emailField() => find.byType(TextField).first;
  Finder passwordField() => find.byType(TextField).last;
  Finder loginButton() =>
      find.widgetWithText(ElevatedButton, 'Login');

  group('Login Widget Tests', () {
    testWidgets('AT03: Empty fields show validation messages',
        (tester) async {
      await openLoginScreen(tester);

      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter your email'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Please enter your password'),
        findsOneWidget,
      );
    });

    testWidgets('AT04: Empty email shows validation message',
        (tester) async {
      await openLoginScreen(tester);

      await tester.enterText(passwordField(), 'ValidPassword123!');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter your email'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Please enter your password'),
        findsNothing,
      );
    });

    testWidgets('AT05: Empty password shows validation message',
        (tester) async {
      await openLoginScreen(tester);

      await tester.enterText(emailField(), 'student@autuni.ac.nz');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter your password'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Please enter your email'),
        findsNothing,
      );
    });

    testWidgets('Invalid university email shows validation message',
        (tester) async {
      await openLoginScreen(tester);

      await tester.enterText(emailField(), 'student@gmail.com');
      await tester.enterText(passwordField(), 'ValidPassword123!');
      await tester.ensureVisible(loginButton());
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Please use your AUT email (@autuni.ac.nz)',
        ),
        findsOneWidget,
      );
    });
  });
}