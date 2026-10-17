import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/models/turf.dart';
import '../fixtures/turf_fixtures.dart';

void main() {
  group('Turf Model', () {
    test('fromJson parses complete valid JSON correctly', () {
      final json = sampleTurfJson();
      final turf = Turf.fromJson(json);

      expect(turf.id, 1);
      expect(turf.name, 'Green Arena Turf');
      expect(turf.type, 'Football / Cricket');
      expect(turf.description, 'Premium turf with floodlights');
      expect(turf.area, 'Andheri West');
      expect(turf.imageUrl, 'https://example.com/turf.jpg');
      expect(turf.imageUrls, ['https://example.com/turf1.jpg', 'https://example.com/turf2.jpg']);
      expect(turf.locationName, 'Mumbai Sports Complex');
      expect(turf.locationAddress, '123 Stadium Road, Andheri West, Mumbai');
      expect(turf.latitude, 19.1136);
      expect(turf.longitude, 72.8697);
      expect(turf.priceText, '₹1,200 / hr');
      expect(turf.rating, '4.5');
      expect(turf.reviewsCount, 42);
      expect(turf.isOnlinePaymentActive, isTrue);
      expect(turf.isPartPaymentActive, isTrue);
      expect(turf.isPayAtLocationActive, isTrue);
      expect(turf.isCancellationActive, isTrue);
      expect(turf.cancellationFee, 100.0);
      expect(turf.cancellationFeePercentage, 10.0);
      expect(turf.cancellationHours, 4);
      expect(turf.isBookingOpen, isTrue);
      expect(turf.bookingOpenDays, 30);
      expect(turf.partPaymentType, 'fixed');
      expect(turf.partPaymentValue, 500.0);
      expect(turf.contactNumber, '9876543210');
      expect(turf.whatsappNumber, '9876543210');
      expect(turf.sports, ['Football', 'Cricket']);
      expect(turf.facilities, ['Parking', 'Dressing Room']);
      expect(turf.equipments, ['Balls', 'Bibs']);
    });

    test('fromJson handles minimal JSON and default values', () {
      final json = {
        'id': 99,
        'name': 'Minimal Turf',
        'type': 'Box Cricket',
        'location_name': 'Downtown',
        'location_address': 'Downtown Ave',
      };
      final turf = Turf.fromJson(json);

      expect(turf.id, 99);
      expect(turf.name, 'Minimal Turf');
      expect(turf.priceText, '₹1,000 / hr');
      expect(turf.rating, '0.0');
      expect(turf.reviewsCount, 0);
      expect(turf.isOnlinePaymentActive, isFalse);
      expect(turf.isPartPaymentActive, isFalse);
      expect(turf.isPayAtLocationActive, isTrue); // default when null
      expect(turf.isCancellationActive, isFalse);
      expect(turf.cancellationFee, 0.0);
      expect(turf.cancellationFeePercentage, 5.0);
      expect(turf.cancellationHours, 0);
      expect(turf.isBookingOpen, isTrue);
      expect(turf.bookingOpenDays, 30);
      expect(turf.imageUrls, isEmpty);
      expect(turf.sports, isEmpty);
      expect(turf.facilities, isEmpty);
      expect(turf.equipments, isEmpty);
    });

    test('boolean coercion for 1 and "1"', () {
      final json = {
        'id': 10,
        'name': 'Flag Test',
        'type': 'Turf',
        'location_name': 'Loc',
        'location_address': 'Addr',
        'is_online_payment_active': 1,
        'is_part_payment_active': '1',
        'is_pay_at_location_active': '1',
        'is_cancellation_active': 1,
      };
      final turf = Turf.fromJson(json);

      expect(turf.isOnlinePaymentActive, isTrue);
      expect(turf.isPartPaymentActive, isTrue);
      expect(turf.isPayAtLocationActive, isTrue);
      expect(turf.isCancellationActive, isTrue);
    });

    test('isPayAtLocationActive false is respected', () {
      final json = {
        'id': 11,
        'name': 'No Cash Turf',
        'type': 'Turf',
        'location_name': 'Loc',
        'location_address': 'Addr',
        'is_pay_at_location_active': false,
      };
      final turf = Turf.fromJson(json);
      expect(turf.isPayAtLocationActive, isFalse);
    });

    test('hasRating returns true only when rating is non-zero', () {
      expect(sampleTurf(rating: '4.8').hasRating, isTrue);
      expect(sampleTurf(rating: '0.0').hasRating, isFalse);
      expect(sampleTurf(rating: '0').hasRating, isFalse);
    });

    test('effectiveContactNumber returns trimmed or empty string', () {
      expect(sampleTurf(contactNumber: ' 9876543210 ').effectiveContactNumber, '9876543210');
      expect(sampleTurf(contactNumber: null).effectiveContactNumber, '');
      expect(sampleTurf(contactNumber: '   ').effectiveContactNumber, '');
    });

    test('effectiveWhatsappNumber falls back to effectiveContactNumber if not provided', () {
      final turfWithWhatsapp = sampleTurf(
        contactNumber: '9876543210',
        whatsappNumber: '9123456789',
      );
      expect(turfWithWhatsapp.effectiveWhatsappNumber, '9123456789');

      final turfWithoutWhatsapp = sampleTurf(
        contactNumber: '9876543210',
        whatsappNumber: null,
      );
      expect(turfWithoutWhatsapp.effectiveWhatsappNumber, '9876543210');

      final turfWithEmptyWhatsapp = sampleTurf(
        contactNumber: '9876543210',
        whatsappNumber: '  ',
      );
      expect(turfWithEmptyWhatsapp.effectiveWhatsappNumber, '9876543210');
    });
  });
}
