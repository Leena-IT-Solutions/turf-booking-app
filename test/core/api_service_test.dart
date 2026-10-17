import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/services/api_service.dart';

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

  group('ApiService reschedule tests', () {
    test('getRescheduleSlots parses slots correctly on 200', () async {
      final jsonResponse = {
        'booking_date_id': 101,
        'date': '2026-10-25',
        'slots': [
          {
            'id': 1,
            'from_time': '06:00:00',
            'to_time': '07:00:00',
            'time_label': '06:00 AM - 07:00 AM',
            'price': 1000.0,
            'is_available': true,
            'is_current_slot': false,
          },
          {
            'id': 2,
            'from_time': '07:00:00',
            'to_time': '08:00:00',
            'time_label': '07:00 AM - 08:00 AM',
            'price': 1200.0,
            'is_available': false,
            'is_current_slot': false,
          },
        ],
      };

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final res = await ApiService.getRescheduleSlots(101, '2026-10-25', token: 'test-token');

      expect(res['success'], isTrue);
      final List<RescheduleSlot> slots = res['slots'] as List<RescheduleSlot>;
      expect(slots.length, 2);
      expect(slots[0].timeRange, '06:00 AM - 07:00 AM');
      expect(slots[0].isAvailable, isTrue);
      expect(slots[1].isAvailable, isFalse);

      final calledUri = verify(() => mockClient.get(captureAny(), headers: any(named: 'headers'))).captured.single as Uri;
      expect(calledUri.path, endsWith('/booking-dates/101/reschedule/slots'));
      expect(calledUri.queryParameters['date'], '2026-10-25');
    });

    test('previewReschedule parses price comparison correctly', () async {
      final jsonResponse = {
        'success': true,
        'from_date': '2026-10-20',
        'to_date': '2026-10-22',
        'old_amount': 1000.0,
        'new_amount': 2500.0,
        'price_difference': 1500.0,
        'settlement_type': 'balance_due',
        'refund_amount': 0.0,
        'refund_channel': null,
      };

      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response.bytes(
                utf8.encode(jsonEncode(jsonResponse)),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ));

      final res = await ApiService.previewReschedule(101, '2026-10-22', [1, 2], token: 'test-token');

      expect(res['success'], isTrue);
      final ReschedulePreview preview = res['preview'] as ReschedulePreview;
      expect(preview.difference, 1500.0);
      expect(preview.direction, 'extra_charge');
      expect(preview.oldAmount, 1000.0);
      expect(preview.newAmount, 2500.0);
      expect(preview.newSlotCount, 2);

      final calledUri = verify(() => mockClient.post(captureAny(), headers: any(named: 'headers'), body: any(named: 'body'))).captured.single as Uri;
      expect(calledUri.path, endsWith('/booking-dates/101/reschedule/preview'));
    });

    test('previewReschedule maps a server refund to direction refund via gateway', () async {
      final jsonResponse = {
        'success': true,
        'from_date': '2026-10-24',
        'to_date': '2026-10-26',
        'old_amount': 1500.0,
        'new_amount': 1000.0,
        'price_difference': -500.0,
        'settlement_type': 'refund',
        'refund_amount': 500.0,
        'refund_channel': 'online_gateway',
      };
      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final res = await ApiService.previewReschedule(101, '2026-10-26', [1], token: 'test-token');
      final ReschedulePreview preview = res['preview'] as ReschedulePreview;
      expect(preview.direction, 'refund');
      expect(preview.refundChannel, 'gateway');
      expect(preview.difference, -500.0);
    });

    test('rescheduleBooking performs reschedule and returns success', () async {
      final jsonResponse = {
        'success': true,
        'message': 'Session rescheduled successfully.',
        'reschedule': {'id': 1, 'booking_date_id': 101, 'to_date': '2026-10-22'},
      };

      when(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final res = await ApiService.rescheduleBooking(
        101,
        '2026-10-22',
        [1],
        reason: 'Customer requested change',
        token: 'test-token',
      );

      expect(res['success'], isTrue);
      expect(res['message'], 'Session rescheduled successfully.');
    });
  });
}
