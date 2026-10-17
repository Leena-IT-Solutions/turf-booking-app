import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/models/booking.dart';
import 'package:turf_booking/widgets/record_payment_dialog.dart';
import '../fixtures/booking_fixtures.dart';

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

  Widget buildTestableDialog({
    required Booking booking,
    String? token = 'manager-token-123',
    VoidCallback? onSuccess,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RecordPaymentDialog(
                    bookingDate: booking,
                    token: token,
                    onSuccess: onSuccess,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('RecordPaymentDialog Tests', () {
    testWidgets('renders payment dialog with default Cash and pre-filled balance amount', (WidgetTester tester) async {
      setTestScreenSize(tester);
      final booking = sampleBooking(
        id: 501,
        dateBalanceAmount: 450.0,
      );

      await tester.pumpWidget(buildTestableDialog(booking: booking));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Record Offline Payment'), findsOneWidget);
      expect(find.text('Select Payment Method:'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('450.00'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('shows validation snackbar when amount is 0 or negative', (WidgetTester tester) async {
      setTestScreenSize(tester);
      final booking = sampleBooking(
        id: 501,
        dateBalanceAmount: 0.0,
      );

      await tester.pumpWidget(buildTestableDialog(booking: booking));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });

    testWidgets('shows error snackbar on API failure', (WidgetTester tester) async {
      setTestScreenSize(tester);
      final booking = sampleBooking(
        id: 501,
        dateBalanceAmount: 500.0,
      );

      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/booking-dates/501/payments'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'message': 'Amount exceeds remaining balance'}),
            422,
          ));

      await tester.pumpWidget(buildTestableDialog(booking: booking));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      expect(find.text('Amount exceeds remaining balance'), findsOneWidget);
    });

    testWidgets('submits payment successfully and triggers onSuccess callback', (WidgetTester tester) async {
      setTestScreenSize(tester);
      bool successCalled = false;
      final booking = sampleBooking(
        id: 501,
        dateBalanceAmount: 750.0,
      );

      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/booking-dates/501/payments'),
            headers: any(named: 'headers'),
            body: jsonEncode({
              'payment_method': 'Cash',
              'amount': 750.0,
            }),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'message': 'Payment recorded successfully.'}),
            200,
          ));

      await tester.pumpWidget(buildTestableDialog(
        booking: booking,
        onSuccess: () => successCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      expect(successCalled, isTrue);
      // Dialog should be dismissed
      expect(find.text('Record Offline Payment'), findsNothing);
    });
  });
}
