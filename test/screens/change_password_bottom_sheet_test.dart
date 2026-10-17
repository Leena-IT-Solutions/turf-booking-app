import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/widgets/change_password_bottom_sheet.dart';

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

  void setTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableSheet({
    String token = 'test-token',
    VoidCallback? onSuccess,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ChangePasswordBottomSheet(
                    token: token,
                    onSuccess: onSuccess ?? () {},
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
  }

  group('ChangePasswordBottomSheet Tests', () {
    testWidgets('shows validation error when current password is empty and does not submit', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableSheet());
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'newpassword123');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter current password'), findsOneWidget);
      verifyNever(() => mockClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    testWidgets('shows validation error when new password is under 6 characters', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableSheet());
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'currentpass');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), '12345');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), '12345');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      verifyNever(() => mockClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    testWidgets('shows validation error when passwords do not match', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableSheet());
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'currentpass');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'newpassword123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'mismatched123');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => mockClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    testWidgets('submits successfully and calls onSuccess on 200 response', (WidgetTester tester) async {
      setTestScreenSize(tester);

      bool successCalled = false;

      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/password'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Password updated successfully.',
          }),
          200,
        ),
      );

      await tester.pumpWidget(buildTestableSheet(
        onSuccess: () => successCalled = true,
      ));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'password');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'newpass123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'newpass123');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(successCalled, isTrue);
      // Sheet should be popped
      expect(find.text('Change Password'), findsNothing);
    });

    testWidgets('shows error snackbar and keeps sheet open when API returns 422', (WidgetTester tester) async {
      setTestScreenSize(tester);

      bool successCalled = false;

      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/password'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Current password does not match our records.',
          }),
          422,
        ),
      );

      await tester.pumpWidget(buildTestableSheet(
        onSuccess: () => successCalled = true,
      ));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'wrongpass');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'newpass123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'newpass123');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password does not match our records.'), findsOneWidget);
      expect(successCalled, isFalse);
      // Sheet should stay open
      expect(find.text('Change Password'), findsOneWidget);
    });
  });
}
