import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/core/notification_service.dart';

void main() {
  tearDown(() {
    NotificationService.onNavigateToBooking = null;
  });

  group('NotificationService.handleMessageData', () {
    test('returns early without invoking callback for custom_notification', () {
      bool callbackCalled = false;
      NotificationService.onNavigateToBooking = (_) {
        callbackCalled = true;
      };

      NotificationService.handleMessageData({
        'type': 'custom_notification',
        'title': 'Announcements',
        'booking_id': '42',
      });

      expect(callbackCalled, isFalse);
    });

    test('invokes onNavigateToBooking with correct id for booking_created', () {
      String? routedBookingId;
      NotificationService.onNavigateToBooking = (bookingId) {
        routedBookingId = bookingId;
      };

      NotificationService.handleMessageData({
        'type': 'booking_created',
        'booking_id': '42',
      });

      expect(routedBookingId, '42');
    });

    test('invokes onNavigateToBooking with correct id for booking_cancelled', () {
      String? routedBookingId;
      NotificationService.onNavigateToBooking = (bookingId) {
        routedBookingId = bookingId;
      };

      NotificationService.handleMessageData({
        'type': 'booking_cancelled',
        'booking_id': '17',
      });

      expect(routedBookingId, '17');
    });

    test('invokes onNavigateToBooking with correct id for payment_received', () {
      String? routedBookingId;
      NotificationService.onNavigateToBooking = (bookingId) {
        routedBookingId = bookingId;
      };

      NotificationService.handleMessageData({
        'type': 'payment_received',
        'booking_id': '5',
      });

      expect(routedBookingId, '5');
    });

    test('does not invoke callback when booking_id is empty or null', () {
      bool callbackCalled = false;
      NotificationService.onNavigateToBooking = (_) {
        callbackCalled = true;
      };

      NotificationService.handleMessageData({
        'type': 'booking_created',
        'booking_id': '',
      });

      expect(callbackCalled, isFalse);

      NotificationService.handleMessageData({
        'type': 'booking_created',
      });

      expect(callbackCalled, isFalse);
    });
  });
}
