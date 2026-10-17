import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/widgets/edit_profile_bottom_sheet.dart';

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
    String initialName = 'Sandeep Rathod',
    String initialEmail = 'sandeep198558@gmail.com',
    String initialMobile = '9664588677',
    void Function(String name, String email, String mobile)? onSuccess,
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
                  builder: (_) => EditProfileBottomSheet(
                    token: token,
                    initialName: initialName,
                    initialEmail: initialEmail,
                    initialMobile: initialMobile,
                    onSuccess: onSuccess ?? (name, email, mobile) {},
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

  group('EditProfileBottomSheet Tests', () {
    testWidgets('shows validation errors when fields are empty and does not submit', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableSheet(
        initialName: '',
        initialEmail: '',
        initialMobile: '',
      ));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter email'), findsOneWidget);
      expect(find.text('Please enter mobile number'), findsOneWidget);

      verifyNever(() => mockClient.put(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ));
    });

    testWidgets('submits successfully and calls onSuccess with updated values on 200 response', (WidgetTester tester) async {
      setTestScreenSize(tester);

      String? submittedName;
      String? submittedEmail;
      String? submittedMobile;

      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/profile'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Profile details updated successfully.',
            'user': {
              'name': 'Updated Name',
              'email': 'updated@example.com',
              'mobile': '9876543210',
            },
          }),
          200,
        ),
      );

      await tester.pumpWidget(buildTestableSheet(
        initialName: 'Initial Name',
        initialEmail: 'initial@example.com',
        initialMobile: '1234567890',
        onSuccess: (name, email, mobile) {
          submittedName = name;
          submittedEmail = email;
          submittedMobile = mobile;
        },
      ));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Updated Name');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'updated@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number'), '9876543210');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(submittedName, 'Updated Name');
      expect(submittedEmail, 'updated@example.com');
      expect(submittedMobile, '9876543210');

      // The bottom sheet should have popped
      expect(find.text('Edit Personal Details'), findsNothing);
    });

    testWidgets('shows error snackbar and keeps sheet open when API fails', (WidgetTester tester) async {
      setTestScreenSize(tester);

      bool successCalled = false;

      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/profile'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'The email has already been taken.',
          }),
          422,
        ),
      );

      await tester.pumpWidget(buildTestableSheet(
        onSuccess: (name, email, mobile) {
          successCalled = true;
        },
      ));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('The email has already been taken.'), findsOneWidget);
      expect(successCalled, isFalse);
      // Sheet should remain open
      expect(find.text('Edit Personal Details'), findsOneWidget);
    });
  });
}
