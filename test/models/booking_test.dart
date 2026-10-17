import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/models/booking.dart';
import '../fixtures/booking_fixtures.dart';

void main() {
  group('BookedSlot Model', () {
    test('fromJson parses fields correctly', () {
      final slot = BookedSlot.fromJson({
        'time_range': '07:00 AM - 08:00 AM',
        'from_time': '07:00:00',
        'to_time': '08:00:00',
      });
      expect(slot.timeRange, '07:00 AM - 08:00 AM');
      expect(slot.fromTime, '07:00:00');
      expect(slot.toTime, '08:00:00');
    });
  });

  group('BookingPayment Model', () {
    test('fromJson parses numeric and string amounts', () {
      final p1 = BookingPayment.fromJson({
        'payment_method': 'razorpay',
        'amount': 500,
        'paid_at': '2026-10-17 10:00:00',
      });
      expect(p1.paymentMethod, 'razorpay');
      expect(p1.amount, 500.0);
      expect(p1.paidAt, '2026-10-17 10:00:00');

      final p2 = BookingPayment.fromJson({
        'payment_method': 'cash',
        'amount': '250.50',
      });
      expect(p2.amount, 250.50);
    });
  });

  group('CancellationBreakup Model', () {
    test('fromJson handles aliases and parsing', () {
      final b1 = CancellationBreakup.fromJson({
        'gross_paid': 1000,
        'turf_cancellation_fee': 100,
        'platform_fee_retained': 20,
        'saas_cancellation_fee': 10,
        'total_deductions': 130,
        'refund_amount': 870,
      });
      expect(b1.grossPaid, 1000.0);
      expect(b1.turfCancellationFee, 100.0);
      expect(b1.platformFeeRetained, 20.0);
      expect(b1.saasCancellationFee, 10.0);
      expect(b1.totalDeductions, 130.0);
      expect(b1.refundAmount, 870.0);

      // Test aliases 'gross', 'total', 'refund'
      final b2 = CancellationBreakup.fromJson({
        'gross': 500,
        'total': 50,
        'refund': 450,
      });
      expect(b2.grossPaid, 500.0);
      expect(b2.totalDeductions, 50.0);
      expect(b2.refundAmount, 450.0);
    });
  });

  group('Booking Model', () {
    test('fromJson parses complete valid JSON correctly', () {
      final json = sampleBookingJson(
        cancellationBreakup: sampleCancellationBreakupJson(),
        allDatesCancellationBreakup: sampleCancellationBreakupJson(),
      );
      final booking = Booking.fromJson(json);

      expect(booking.id, 101);
      expect(booking.bookingId, 202);
      expect(booking.bookingNumber, 'TB-2026-001');
      expect(booking.turfId, '1');
      expect(booking.turfName, 'Green Arena Turf');
      expect(booking.customerName, 'Sandeep Rathod');
      expect(booking.customerMobile, '9664588677');
      expect(booking.customerEmail, 'sandeep198558@gmail.com');
      expect(booking.status, 'Confirmed');
      expect(booking.datePaymentStatus, 'Paid');
      expect(booking.bookingType, 'day');
      expect(booking.bookingDate, '17 Oct 2026');
      expect(booking.actualAmount, 1200.0);
      expect(booking.couponDiscount, 100.0);
      expect(booking.taxableAmount, 1100.0);
      expect(booking.turfGstRate, 18.0);
      expect(booking.turfGstAmount, 198.0);
      expect(booking.platformFee, 20.0);
      expect(booking.platformFeeGst, 3.6);
      expect(booking.amount, 1321.6);
      expect(booking.datePaidAmount, 1321.6);
      expect(booking.dateBalanceAmount, 0.0);
      expect(booking.slots.length, 1);
      expect(booking.payments.length, 1);
      expect(booking.isCancellationActive, isTrue);
      expect(booking.cancellationHours, 4);
      expect(booking.cancellationBreakup, isNotNull);
      expect(booking.allDatesCancellationBreakup, isNotNull);
      expect(booking.isConfirmed, isTrue);
      expect(booking.isCancelled, isFalse);
      expect(booking.isPaid, isTrue);
    });

    test('fromJson handles minimal JSON and default fallback values', () {
      final json = {
        'id': 1,
        'booking_id': 1,
        'turf_name': 'Simple Turf',
      };
      final booking = Booking.fromJson(json);

      expect(booking.id, 1);
      expect(booking.bookingId, 1);
      expect(booking.turfName, 'Simple Turf');
      expect(booking.status, 'Pending');
      expect(booking.datePaymentStatus, 'Unpaid');
      expect(booking.bookingType, 'day');
      expect(booking.amount, 0.0);
      expect(booking.datePaidAmount, 0.0);
      expect(booking.dateBalanceAmount, 0.0);
      expect(booking.slots, isEmpty);
      expect(booking.payments, isEmpty);
      expect(booking.isCancellationActive, isFalse);
      expect(booking.cancellationHours, 0);
      expect(booking.isConfirmed, isFalse);
      expect(booking.isPaid, isFalse);
    });

    test('paid status forces balance to 0 and datePaidAmount to full amount if smaller', () {
      final json = {
        'id': 2,
        'booking_id': 2,
        'turf_name': 'Turf',
        'date_payment_status': 'Paid',
        'amount': 1500.0,
        'date_paid_amount': 500.0,
        'date_balance_amount': 1000.0,
      };
      final booking = Booking.fromJson(json);

      expect(booking.datePaidAmount, 1500.0);
      expect(booking.dateBalanceAmount, 0.0);
    });

    test('safeCancellationBreakup returns explicit breakup when present', () {
      final explicitBreakup = const CancellationBreakup(
        grossPaid: 1000,
        turfCancellationFee: 100,
        platformFeeRetained: 20,
        saasCancellationFee: 0,
        totalDeductions: 120,
        refundAmount: 880,
      );
      final booking = sampleBooking(cancellationBreakup: explicitBreakup);

      expect(booking.safeCancellationBreakup, equals(explicitBreakup));
    });

    test('safeCancellationBreakup computes fallback correctly when breakup is null', () {
      final booking = sampleBooking(
        cancellationBreakup: null,
        datePaidAmount: 1000.0,
        cancellationFee: 150.0,
        cancellationFeeApplied: 0.0,
        refundAmount: 0.0,
      );

      final breakup = booking.safeCancellationBreakup;
      expect(breakup.grossPaid, 1000.0);
      expect(breakup.turfCancellationFee, 150.0);
      expect(breakup.totalDeductions, 150.0);
      expect(breakup.refundAmount, 850.0);
    });

    test('formattedTimeRange formats from slots with timeRange', () {
      final booking = sampleBooking(
        slots: const [
          BookedSlot(timeRange: '06:00 PM - 07:00 PM'),
          BookedSlot(timeRange: '07:00 PM - 08:00 PM'),
        ],
      );
      expect(booking.formattedTimeRange(), '06:00 PM - 08:00 PM');
    });

    test('formattedTimeRange formats from slots with fromTime/toTime', () {
      final booking = sampleBooking(
        slots: const [
          BookedSlot(fromTime: '18:00', toTime: '19:00'),
          BookedSlot(fromTime: '19:00', toTime: '20:00'),
        ],
      );
      expect(booking.formattedTimeRange(), '18:00 - 20:00');
    });

    test('formattedTimeRange fallback to summaryText or N/A', () {
      final bookingWithSlotWord = sampleBooking(
        slots: const [],
        summaryText: '2 slots booked',
      );
      expect(bookingWithSlotWord.formattedTimeRange(), 'N/A');

      final bookingWithCustomSummary = sampleBooking(
        slots: const [],
        summaryText: 'Morning Session',
      );
      expect(bookingWithCustomSummary.formattedTimeRange(), 'Morning Session');

      final bookingEmpty = sampleBooking(
        slots: const [],
        summaryText: null,
      );
      expect(bookingEmpty.formattedTimeRange(), 'N/A');
    });

    test('isPast correctly compares dateRaw with current date', () {
      final pastBooking = sampleBooking(dateRaw: '2020-01-01');
      expect(pastBooking.isPast(), isTrue);

      final futureBooking = sampleBooking(dateRaw: '2099-12-31');
      expect(futureBooking.isPast(), isFalse);

      final emptyDateBooking = sampleBooking(dateRaw: null);
      expect(emptyDateBooking.isPast(), isFalse);
    });
  });
}
