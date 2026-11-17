import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/core/notification_service.dart';

void main() {
  setUp(() {
    NotificationService.resetForTesting();
  });

  group('NotificationService.resolveRoute', () {
    test('routes customer booking, reminder, payment, and refund events to Bookings tab', () {
      for (final type in [
        'booking_created',
        'booking_cancelled',
        'booking_rescheduled',
        'payment_received',
        'match_reminder',
        'refund_processed',
      ]) {
        final route = NotificationService.resolveRoute({
          'type': type,
          'booking_id': '42',
        });
        expect(route.target, NotificationRouteTarget.bookings, reason: 'Failed for $type');
        expect(route.bookingId, '42');
      }
    });

    test('routes venue booking and daily digest events to Client Bookings tab', () {
      for (final type in [
        'manager_booking_created',
        'manager_booking_cancelled',
        'manager_booking_rescheduled',
        'daily_digest',
      ]) {
        final route = NotificationService.resolveRoute({
          'type': type,
          'booking_id': '99',
          'turf_id': '7',
        });
        expect(route.target, NotificationRouteTarget.clientBookings, reason: 'Failed for $type');
        expect(route.turfId, 7);
      }
    });

    test('routes support chat messages to Support tab', () {
      for (final type in ['support_reply', 'admin_support_message']) {
        final route = NotificationService.resolveRoute({'type': type});
        expect(route.target, NotificationRouteTarget.support, reason: 'Failed for $type');
      }
    });

    test('routes review prompts and new offers with turf_id to TurfDetailScreen', () {
      for (final type in ['review_prompt', 'new_offer']) {
        final route = NotificationService.resolveRoute({
          'type': type,
          'turf_id': '15',
        });
        expect(route.target, NotificationRouteTarget.turfDetail, reason: 'Failed for $type');
        expect(route.turfId, 15);
      }
    });

    test('routes verification, payouts, reviews, trial, and invoices to Dashboard tab', () {
      for (final type in [
        'turf_verification',
        'payout_paid',
        'payout_rejected',
        'new_review',
        'trial_expiring',
        'commission_invoice',
        'admin_turf_submitted',
        'manual_payout_requested',
        'admin_payout_failed',
      ]) {
        final route = NotificationService.resolveRoute({'type': type});
        expect(route.target, NotificationRouteTarget.dashboard, reason: 'Failed for $type');
      }
    });

    test('ignores custom_notification broadcast taps', () {
      final route = NotificationService.resolveRoute({'type': 'custom_notification'});
      expect(route.target, NotificationRouteTarget.none);
    });
  });

  group('Cold-start tap queueing and Android channels', () {
    test('queues tap before MainScreen mounts and replays immediately on registerTapHandler', () {
      NotificationRoute? received;

      // Simulate cold-start tap arriving before MainScreen mounts
      NotificationService.handleMessageData({
        'type': 'review_prompt',
        'turf_id': '21',
      });
      expect(received, isNull);

      // MainScreen mounts and registers its tap handler
      NotificationService.registerTapHandler((route) {
        received = route;
      });

      expect(received, isNotNull);
      expect(received!.target, NotificationRouteTarget.turfDetail);
      expect(received!.turfId, 21);
    });

    test('defines categorized Android notification channels', () {
      final channelIds = NotificationService.androidChannels.map((c) => c.id).toSet();
      expect(
        channelIds,
        containsAll(['bookings', 'reminders', 'offers', 'payouts', 'support']),
      );
    });
  });
}
