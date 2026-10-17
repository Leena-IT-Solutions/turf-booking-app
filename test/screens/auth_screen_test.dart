import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/screens/auth_screen.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.client = mockClient;
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  Widget buildTestableAuthScreen({required Function(String, Map<String, dynamic>) onLoginSuccess}) {
    return MaterialApp(
      home: AuthScreen(onLoginSuccess: onLoginSuccess),
    );
  }

  void setTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('AuthScreen Tests', () {
    testWidgets('renders all initial login form elements', (WidgetTester tester) async {
      setTestScreenSize(tester);
      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Email or Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('shows validation error messages when fields are empty', (WidgetTester tester) async {
      setTestScreenSize(tester);
      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter email or mobile'), findsOneWidget);
      expect(find.text('Please enter password'), findsOneWidget);
    });

    testWidgets('toggles password visibility when icon tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      // Initially password is obscured, so suffix icon is visibility_off
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Now unobscured, icon becomes visibility
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('shows error message on failed login response (401)', (WidgetTester tester) async {
      setTestScreenSize(tester);
      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/login'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'message': 'Invalid login credentials'}),
            401,
          ));

      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'invalid@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid login credentials'), findsOneWidget);
    });

    testWidgets('calls onLoginSuccess on successful credentials (200)', (WidgetTester tester) async {
      setTestScreenSize(tester);
      String? receivedToken;
      Map<String, dynamic>? receivedUser;

      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/login'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'access_token': 'fake-jwt-token-123',
              'user': {
                'id': 1,
                'name': 'Sandeep Rathod',
                'email': 'sandeep198558@gmail.com',
                'roles': ['customer'],
              },
            }),
            200,
          ));

      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (token, user) {
        receivedToken = token;
        receivedUser = user;
      }));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'sandeep198558@gmail.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password');

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(receivedToken, 'fake-jwt-token-123');
      expect(receivedUser?['name'], 'Sandeep Rathod');
      expect(receivedUser?['email'], 'sandeep198558@gmail.com');
      expect(find.text('Welcome back, Sandeep Rathod!'), findsOneWidget);
    });

    testWidgets('switches to sign up state when Sign Up tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Mobile Number'), findsOneWidget);
      expect(find.text('Send WhatsApp OTP'), findsOneWidget);
    });

    testWidgets('switches to forgot password state when Forgot Password tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      await tester.pumpWidget(buildTestableAuthScreen(onLoginSuccess: (_, _) {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });
  });
}
