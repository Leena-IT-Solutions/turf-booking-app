import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/models/booking.dart';
import 'package:turf_booking/widgets/reschedule_booking_sheet.dart';
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

  Widget buildTestableSheet({
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
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => RescheduleBookingSheet(
                    bookingDate: booking,
                    token: token,
                    onSuccess: onSuccess,
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

  testWidgets('renders RescheduleBookingSheet, loads slots, allows slot selection and preview', (tester) async {
    setTestScreenSize(tester);

    final booking = Booking.fromJson(sampleBookingJson(
      id: 101,
      turfName: 'Downtown Turf',
      amount: 1000.0,
      status: 'Confirmed',
    ));

    final slotsJson = {
      'booking_date_id': 101,
      'date': '2026-10-25',
      'slots': [
        {
          'id': 10,
          'from_time': '07:00:00',
          'to_time': '08:00:00',
          'time_label': '07:00 PM - 08:00 PM',
          'price': 1500.0,
          'is_available': true,
          'is_current_slot': false,
        },
      ],
    };

    final previewJson = {
      'success': true,
      'from_date': '2026-10-20',
      'to_date': '2026-10-25',
      'old_amount': 1000.0,
      'new_amount': 1500.0,
      'price_difference': 500.0,
      'settlement_type': 'balance_due',
      'refund_amount': 0.0,
      'refund_channel': null,
    };

    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(jsonEncode(slotsJson), 200));

    when(() => mockClient.post(
      any(that: predicate<Uri>((u) => u.path.contains('reschedule/preview'))),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async => http.Response.bytes(
          utf8.encode(jsonEncode(previewJson)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    await tester.pumpWidget(buildTestableSheet(booking: booking));
    await tester.tap(find.text('Open Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify header and slots
    expect(find.text('Reschedule Session'), findsOneWidget);
    expect(find.text('07:00 PM - 08:00 PM'), findsOneWidget);

    // Tap slot to select it
    await tester.tap(find.text('07:00 PM - 08:00 PM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify preview card appears
    expect(find.text('Price Comparison'), findsOneWidget);
    expect(find.textContaining('Extra Cash to Collect: ₹500.00'), findsOneWidget);
  });

  testWidgets('confirms reschedule and triggers callback', (tester) async {
    setTestScreenSize(tester);

    bool callbackTriggered = false;
    final booking = Booking.fromJson(sampleBookingJson(
      id: 101,
      turfName: 'Downtown Turf',
      amount: 1000.0,
      status: 'Confirmed',
    ));

    final slotsJson = {
      'booking_date_id': 101,
      'date': '2026-10-25',
      'slots': [
        {
          'id': 10,
          'from_time': '07:00:00',
          'to_time': '08:00:00',
          'time_label': '07:00 PM - 08:00 PM',
          'price': 1000.0,
          'is_available': true,
          'is_current_slot': false,
        },
      ],
    };

    final rescheduleJson = {
      'success': true,
      'message': 'Session rescheduled successfully!',
      'reschedule': {'id': 1, 'booking_date_id': 101, 'to_date': '2026-10-25'},
    };

    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(jsonEncode(slotsJson), 200));

    when(() => mockClient.post(
      any(that: predicate<Uri>((u) => u.path.contains('reschedule/preview'))),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async => http.Response(jsonEncode({
      'success': true,
      'from_date': '2026-10-20',
      'to_date': '2026-10-25',
      'old_amount': 1000.0,
      'new_amount': 1000.0,
      'price_difference': 0.0,
      'settlement_type': 'none',
      'refund_amount': 0.0,
      'refund_channel': null,
    }), 200));

    when(() => mockClient.post(
      any(that: predicate<Uri>((u) => u.path.endsWith('/reschedule'))),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async => http.Response(jsonEncode(rescheduleJson), 200));

    await tester.pumpWidget(buildTestableSheet(
      booking: booking,
      onSuccess: () => callbackTriggered = true,
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap slot
    await tester.tap(find.text('07:00 PM - 08:00 PM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Confirm Reschedule
    await tester.tap(find.text('Confirm Reschedule'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(callbackTriggered, isTrue);
  });
}
