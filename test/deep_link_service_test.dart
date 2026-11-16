import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/core/deep_link_service.dart';

void main() {
  group('DeepLinkService QR Code Extraction', () {
    test('extracts turf code from HTTPS App Link / Universal Link', () {
      final uri = Uri.parse('https://turf.infoleena.com/t/ab12cd34');
      expect(DeepLinkService.extractTurfCodeFromUri(uri), 'AB12CD34');
    });

    test('extracts turf code from custom scheme turfbooking://turf/{code}', () {
      final uri = Uri.parse('turfbooking://turf/XY98ZW12');
      expect(DeepLinkService.extractTurfCodeFromUri(uri), 'XY98ZW12');
    });

    test('extracts turf code from Play Store Install Referrer query string', () {
      const referrer = 'utm_source=qr&turf_code=kp44mn77';
      expect(DeepLinkService.extractTurfCodeFromRawString(referrer), 'KP44MN77');
    });

    test('extracts turf code from deferred clipboard token TURFBOOKING:{code}', () {
      const clip = 'TURFBOOKING:QW11ER22';
      expect(DeepLinkService.extractTurfCodeFromRawString(clip), 'QW11ER22');
    });

    test('returns null for unrelated URLs or text', () {
      expect(DeepLinkService.extractTurfCodeFromUri(Uri.parse('https://turf.infoleena.com/pricing')), isNull);
      expect(DeepLinkService.extractTurfCodeFromRawString('hello world'), isNull);
    });
  });
}
