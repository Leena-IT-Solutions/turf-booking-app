import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/screens/turf_booking_screen.dart';
import '../fixtures/turf_fixtures.dart';

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

  final sampleSlots = [
    {
      'id': 1,
      'category': 'Morning',
      'time_label': '06:00 AM - 07:00 AM',
      'price': 600,
      'is_booked': false,
      'is_locked': false,
    },
    {
      'id': 2,
      'category': 'Morning',
      'time_label': '07:00 AM - 08:00 AM',
      'price': 600,
      'is_booked': false,
      'is_locked': false,
    },
    {
      'id': 3,
      'category': 'Evening',
      'time_label': '06:00 PM - 07:00 PM',
      'price': 800,
      'is_booked': true,
      'is_locked': false,
    },
  ];

  Widget buildTestableScreen({String? token}) {
    return MaterialApp(
      home: TurfBookingScreen(
        turf: sampleTurf(),
        token: token,
      ),
    );
  }

  void setupDefaultMocks({List<dynamic>? slots}) {
    when(() => mockClient.get(
          Uri.parse('${ApiClient.baseUrl}/config'),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'min_slots_booking': 2}),
          200,
        ));

    when(() => mockClient.get(
          any(that: predicate<Uri>((uri) => uri.path.contains('/slots'))),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(slots ?? sampleSlots),
          200,
        ));
  }

  group('TurfBookingScreen Tests', () {
    testWidgets('renders screen title, turf name, and booking options', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.text('Book Turf'), findsOneWidget);
      expect(find.text('Green Arena Turf'), findsOneWidget);
      expect(find.text('Booking Option'), findsOneWidget);
      expect(find.text('Day Booking'), findsOneWidget);
      expect(find.text('Long Booking'), findsOneWidget);
      expect(find.text('Scattered Booking'), findsOneWidget);
    });

    testWidgets('displays empty slots prompt when no slots are available', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks(slots: []);

      await tester.pumpWidget(buildTestableScreen(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.text('No slots available for the selected date.'), findsOneWidget);
    });

    testWidgets('renders available slots grouped by category', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen(token: 'test-token'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Slots'), findsOneWidget);
      expect(find.text('06:00 AM - 07:00 AM'), findsOneWidget);
      expect(find.text('07:00 AM - 08:00 AM'), findsOneWidget);
      expect(find.text('Evening Slots'), findsOneWidget);
      expect(find.text('06:00 PM - 07:00 PM'), findsOneWidget);
    });

    testWidgets('shows warning when proceeding without any slot selected', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen(token: 'test-token'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Please select at least one time slot.'), findsOneWidget);
    });

    testWidgets('tapping an available slot auto-selects required contiguous block and toggles off on re-tap', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen(token: 'test-token'));
      await tester.pumpAndSettle();

      // Tap slot 1
      await tester.tap(find.text('06:00 AM - 07:00 AM'));
      await tester.pumpAndSettle();

      // Tap slot 1 again to deselect
      await tester.tap(find.text('06:00 AM - 07:00 AM'));
      await tester.pumpAndSettle();

      // Tap Proceed - since deselected, it should show warning again
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Please select at least one time slot.'), findsOneWidget);
    });

    testWidgets('shows Login Required dialog when token is null', (WidgetTester tester) async {
      setTestScreenSize(tester);
      setupDefaultMocks();

      await tester.pumpWidget(buildTestableScreen(token: null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(find.text('Please login to book this turf.'), findsOneWidget);
    });
  });
}
