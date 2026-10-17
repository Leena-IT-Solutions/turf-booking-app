import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/models/booking.dart';
import 'package:turf_booking/screens/main/bookings_tab.dart';
import '../fixtures/booking_fixtures.dart';

void main() {
  void setTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableBookingsTab({
    String filter = 'upcoming',
    bool loading = false,
    List<Booking> bookings = const [],
    bool hasMore = false,
    ValueChanged<String>? onFilterChanged,
    Future<void> Function()? onRefresh,
    void Function(BuildContext, Booking)? onShowBookingDetails,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BookingsTab(
          bookingsFilter: filter,
          bookingsLoading: loading,
          bookings: bookings,
          hasMoreBookings: hasMore,
          bookingsScrollController: ScrollController(),
          onFilterChanged: onFilterChanged ?? (_) {},
          onRefresh: onRefresh ?? () async {},
          onShowBookingDetails: onShowBookingDetails ?? (_, _) {},
        ),
      ),
    );
  }

  group('BookingsTab Tests', () {
    testWidgets('renders filter tabs and switches filter on tap', (WidgetTester tester) async {
      setTestScreenSize(tester);
      String? changedFilter;

      await tester.pumpWidget(buildTestableBookingsTab(
        filter: 'upcoming',
        onFilterChanged: (val) => changedFilter = val,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(changedFilter, 'past');
    });

    testWidgets('displays loading indicator when loading with empty bookings', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableBookingsTab(
        loading: true,
        bookings: const [],
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays empty state when bookings list is empty', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableBookingsTab(
        filter: 'upcoming',
        loading: false,
        bookings: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Upcoming Bookings'), findsOneWidget);
      expect(find.text('You don\'t have any future turf bookings. Book a slot to get started!'), findsOneWidget);
    });

    testWidgets('renders list of bookings with details and calls onShowBookingDetails on tap', (WidgetTester tester) async {
      setTestScreenSize(tester);
      Booking? selectedBooking;

      final testBookings = [
        sampleBooking(
          id: 1,
          bookingId: 101,
          turfName: 'Green Arena Turf',
          bookingNumber: 'TB-101',
          status: 'Confirmed',
          amount: 1200.0,
        ),
        sampleBooking(
          id: 2,
          bookingId: 102,
          turfName: 'Sky Sports Turf',
          bookingNumber: 'TB-102',
          status: 'Pending',
          amount: 800.0,
        ),
      ];

      await tester.pumpWidget(buildTestableBookingsTab(
        bookings: testBookings,
        onShowBookingDetails: (_, booking) => selectedBooking = booking,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Green Arena Turf'), findsOneWidget);
      expect(find.text('TB-101'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);

      expect(find.text('Sky Sports Turf'), findsOneWidget);
      expect(find.text('TB-102'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Tap on first booking card
      await tester.tap(find.text('Green Arena Turf'));
      await tester.pumpAndSettle();

      expect(selectedBooking?.id, 1);
      expect(selectedBooking?.turfName, 'Green Arena Turf');
    });
  });
}
