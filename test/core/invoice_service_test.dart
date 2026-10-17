import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/core/invoice_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;
  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late MockHttpClient mockClient;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.client = mockClient;
    tempDir = Directory.systemTemp.createTempSync('invoice_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    ApiClient.client = http.Client();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('InvoiceService.downloadBill', () {
    test('successfully downloads invoice and writes file when API returns 200 with bytes', () async {
      final fakePdfBytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]); // '%PDF-1.4'

      when(
        () => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/bookings/42/invoice'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response.bytes(
          fakePdfBytes,
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      );

      final filePath = await InvoiceService.downloadBill('test-token', 42);

      expect(filePath, isNotNull);
      final savedFile = File(filePath!);
      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.readAsBytesSync(), equals(fakePdfBytes));
      expect(filePath, '${tempDir.path}/Bill_42.pdf');
    });

    test('returns null and writes no file when API returns non-200 status', () async {
      when(
        () => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/bookings/42/invoice'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response('Not Found', 404),
      );

      final filePath = await InvoiceService.downloadBill('test-token', 42);

      expect(filePath, isNull);
      final expectedFile = File('${tempDir.path}/Bill_42.pdf');
      expect(expectedFile.existsSync(), isFalse);
    });

    test('returns null and writes no file when API returns empty bytes', () async {
      when(
        () => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/bookings/42/invoice'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response.bytes(
          Uint8List(0),
          200,
        ),
      );

      final filePath = await InvoiceService.downloadBill('test-token', 42);

      expect(filePath, isNull);
      final expectedFile = File('${tempDir.path}/Bill_42.pdf');
      expect(expectedFile.existsSync(), isFalse);
    });

    test('returns null and writes no file when network throws an exception', () async {
      when(
        () => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/bookings/42/invoice'),
          headers: any(named: 'headers'),
        ),
      ).thenThrow(Exception('Network disconnected'));

      final filePath = await InvoiceService.downloadBill('test-token', 42);

      expect(filePath, isNull);
      final expectedFile = File('${tempDir.path}/Bill_42.pdf');
      expect(expectedFile.existsSync(), isFalse);
    });
  });
}
