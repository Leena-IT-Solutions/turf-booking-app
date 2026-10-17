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
        'success': true,
        'booking_date_id': 101,
        'date': '2026-10-25',
        'is_same_date': false,
        'slots': [
          {
            'id': 1,
            'start_time': '06:00:00',
            'end_time': '07:00:00',
            'time_range': '06:00 AM - 07:00 AM',
            'price': 1000.0,
            'is_available': true,
            'is_current_slot': false,
          },
          {
            'id': 2,
            'start_time': '07:00:00',
            'end_time': '08:00:00',
            'time_range': '07:00 AM - 08:00 AM',
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
    });

    test('previewReschedule parses price comparison correctly', () async {
      final jsonResponse = {
        'success': true,
        'preview': {
          'old_date': '2026-10-20',
          'new_date': '2026-10-22',
          'old_slot_count': 1,
          'new_slot_count': 2,
          'old_amount': 1000.0,
          'new_amount': 2500.0,
          'difference': 1500.0,
          'direction': 'extra_charge',
          'refund_channel': null,
          'message': 'Collect ₹1,500.00 extra at the venue (Cash/UPI).',
        },
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
    });

    test('rescheduleBooking performs reschedule and returns success', () async {
      final jsonResponse = {
        'success': true,
        'message': 'Session rescheduled successfully.',
        'booking_date_id': 101,
        'new_date': '2026-10-22',
        'difference': 0.0,
        'direction': 'equal',
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
