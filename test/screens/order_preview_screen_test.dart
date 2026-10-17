import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/core/booking_type.dart';
import 'package:turf_booking/screens/order_preview_screen.dart';
import '../fixtures/turf_fixtures.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (call) async => <dynamic, dynamic>{});
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.client = mockClient;
    SharedPreferences.setMockInitialValues({
      'user_name': 'Sandeep Rathod',
      'user_email': 'sandeep198558@gmail.com',
      'user_mobile': '9664588677',
      'user_roles': ['customer'],
    });
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

  Map<String, dynamic> samplePreviewJson({
    double subtotal = 1200.0,
    double couponDiscount = 0.0,
    double totalAmount = 1220.0,
    double payableNow = 1220.0,
    Map<String, dynamic>? couponData,
  }) {
    return {
      'subtotal': subtotal,
      'coupon_discount': couponDiscount,
      'additional_discount': 0.0,
      'turf_gst_amount': 0.0,
      'turf_gst_rate': 0.0,
      'turf_gst_type': 'exclusive',
      'platform_fee': 20.0,
      'platform_fee_gst': 0.0,
      'total_amount': totalAmount,
      'payable_now': payableNow,
      'is_online_payment_active': true,
      'is_part_payment_active': true,
      'is_pay_at_location_active': true,
      'dates': [
        {
          'date': '2026-10-17',
          'subtotal': subtotal,
          'coupon': couponData,
        }
      ],
    };
  }

  void setupDefaultMocks({Map<String, dynamic>? previewJson}) {
    when(() => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/config'),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'razorpay_key': 'rzp_test_mock_key'}),
          200,
        ));

    when(() => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/user'),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'name': 'Sandeep Rathod',
            'email': 'sandeep198558@gmail.com',
            'roles': ['customer'],
          }),
          200,
        ));

    when(() => mockClient.post(
          any(that: predicate<Uri>((uri) => uri.path.endsWith('/bookings/preview'))),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(previewJson ?? samplePreviewJson()),
          200,
        ));
  }

  Widget buildTestableScreen() {
    return MaterialApp(
      home: OrderPreviewScreen(
        turf: sampleTurf(
          id: 1,
          name: 'Green Arena Turf',
          imageUrl: null,
          imageUrls: const [],
        ),
        token: 'test-token-123',
        selectedSlotIds: const [1, 2],
        selectedSlots: const [
          {'id': 1, 'time_label': '06:00 AM - 07:00 AM', 'price': 600},
          {'id': 2, 'time_label': '07:00 AM - 08:00 AM', 'price': 600},
        ],
        bookingType: BookingType.day,
        dates: const ['2026-10-17'],
      ),
    );
  }

  group('OrderPreviewScreen Tests', () {
    testWidgets('renders order preview with pricing and payment options', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Order Preview'), findsOneWidget);
      expect(find.text('Green Arena Turf'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Pay Online'), findsOneWidget);
      expect(find.text('Part Payment'), findsOneWidget);
      expect(find.text('Pay at Location'), findsOneWidget);
    });

    testWidgets('completes booking when selecting Pay at Location and confirming', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/turfs/1/bookings'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'id': 101, 'message': 'Booking confirmed'}),
            200,
          ));

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Ensure Pay at Location is visible and tap
      final payAtLocationFinder = find.text('Pay at Location');
      await tester.ensureVisible(payAtLocationFinder);
      await tester.tap(payAtLocationFinder);
      await tester.pumpAndSettle();

      // Button should now say "Confirm Booking"
      final confirmBtn = find.text('Confirm Booking');
      expect(confirmBtn, findsOneWidget);

      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text('Your booking is confirmed! Please pay at the location.'), findsOneWidget);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('triggers backend order creation when Pay Online is selected', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      when(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/turfs/1/bookings/order'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'order_id': 'order_mock_123',
              'key': 'rzp_test_mock_key',
            }),
            200,
          ));

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Default payment method is online, button says "Pay & Confirm"
      final payConfirmBtn = find.text('Pay & Confirm');
      expect(payConfirmBtn, findsOneWidget);

      await tester.ensureVisible(payConfirmBtn);
      await tester.tap(payConfirmBtn);
      await tester.pump();

      verify(() => mockClient.post(
            Uri.parse('${ApiClient.baseUrl}/turfs/1/bookings/order'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    testWidgets('applies coupon successfully and updates preview discount', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      // Mock preview response after applying coupon
      when(() => mockClient.post(
            any(that: predicate<Uri>((uri) => uri.path.endsWith('/bookings/preview'))),
            headers: any(named: 'headers'),
            body: any(that: contains('SAVE50'), named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(samplePreviewJson(
              subtotal: 1200.0,
              couponDiscount: 50.0,
              totalAmount: 1170.0,
              payableNow: 1170.0,
              couponData: {
                'code': 'SAVE50',
                'applied': true,
                'discount': 50.0,
              },
            )),
            200,
          ));

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final couponField = find.widgetWithText(TextField, 'Enter coupon code');
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'SAVE50');

      final applyBtn = find.text('Apply');
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Coupon "SAVE50" applied successfully!'), findsOneWidget);
    });

    testWidgets('shows error when coupon is invalid', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      when(() => mockClient.post(
            any(that: predicate<Uri>((uri) => uri.path.endsWith('/bookings/preview'))),
            headers: any(named: 'headers'),
            body: any(that: contains('INVALID'), named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(samplePreviewJson(
              couponData: {
                'code': 'INVALID',
                'applied': false,
                'error': 'Coupon code does not exist or expired.',
              },
            )),
            200,
          ));

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final couponField = find.widgetWithText(TextField, 'Enter coupon code');
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'INVALID');

      final applyBtn = find.text('Apply');
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Coupon code does not exist or expired.'), findsWidgets);
    });
  });
}
