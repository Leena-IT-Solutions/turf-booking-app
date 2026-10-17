import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/models/booking.dart';
import 'package:turf_booking/screens/main/client_bookings_tab.dart';
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

  Widget buildTestableClientBookingsTab({
    List<dynamic> manageableTurfs = const [
      {'id': 1, 'name': 'Green Arena Turf'},
      {'id': 2, 'name': 'Sky Sports Turf'},
    ],
    int? selectedTurfId,
    String filter = 'all',
    DateTime? selectedDate,
    bool loading = false,
    List<Booking> bookings = const [],
    ValueChanged<int?>? onTurfFilterChanged,
    ValueChanged<String>? onStatusFilterChanged,
    ValueChanged<DateTime>? onDateChanged,
    Future<void> Function()? onRefresh,
    void Function(BuildContext, Booking)? onShowBookingDetails,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ClientBookingsTab(
          manageableTurfs: manageableTurfs,
          clientBookingSelectedTurfId: selectedTurfId,
          clientBookingFilter: filter,
          clientBookingSelectedDate: selectedDate ?? DateTime(2026, 10, 17),
          clientBookingsLoading: loading,
          clientBookings: bookings,
          onTurfFilterChanged: onTurfFilterChanged ?? (_) {},
          onStatusFilterChanged: onStatusFilterChanged ?? (_) {},
          onDateChanged: onDateChanged ?? (_) {},
          onRefresh: onRefresh ?? () async {},
          onShowBookingDetails: onShowBookingDetails ?? (_, _) {},
        ),
      ),
    );
  }

  group('ClientBookingsTab Tests', () {
    testWidgets('renders turf dropdown, status filter chips, and date navigation', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableClientBookingsTab());
      await tester.pumpAndSettle();

      expect(find.text('Select Turf:'), findsOneWidget);
      expect(find.text('All Turfs'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('17 Oct 2026'), findsOneWidget);
    });

    testWidgets('triggers onStatusFilterChanged when filter chip is tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      String? updatedFilter;

      await tester.pumpWidget(buildTestableClientBookingsTab(
        filter: 'all',
        onStatusFilterChanged: (filter) => updatedFilter = filter,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(updatedFilter, 'upcoming');
    });

    testWidgets('triggers onDateChanged when next date chevron is tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      DateTime? updatedDate;
      final initialDate = DateTime(2026, 10, 17);

      await tester.pumpWidget(buildTestableClientBookingsTab(
        selectedDate: initialDate,
        onDateChanged: (date) => updatedDate = date,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(updatedDate, DateTime(2026, 10, 18));
    });

    testWidgets('displays empty state when client bookings list is empty', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableClientBookingsTab(bookings: const []));
      await tester.pumpAndSettle();

      expect(find.text('No bookings for this date'), findsOneWidget);
    });

    testWidgets('renders client bookings list with customer details and invokes onShowBookingDetails', (WidgetTester tester) async {
      setTestScreenSize(tester);
      Booking? selectedBooking;

      final testBookings = [
        sampleBooking(
          id: 501,
          bookingId: 701,
          turfName: 'Green Arena Turf',
          bookingNumber: 'CB-701',
          customerName: 'Leena Adam',
          customerMobile: '9769409405',
          status: 'Confirmed',
          datePaymentStatus: 'Paid',
          datePaidAmount: 1500.0,
          dateBalanceAmount: 0.0,
          amount: 1500.0,
          dateRaw: '2026-10-17',
        ),
      ];

      await tester.pumpWidget(buildTestableClientBookingsTab(
        bookings: testBookings,
        onShowBookingDetails: (_, booking) => selectedBooking = booking,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Green Arena Turf'), findsOneWidget);
      expect(find.text('CB-701'), findsOneWidget);
      expect(find.text('Leena Adam'), findsOneWidget);
      expect(find.text(' (9769409405)'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);

      await tester.tap(find.text('Green Arena Turf'));
      await tester.pumpAndSettle();

      expect(selectedBooking?.id, 501);
      expect(selectedBooking?.customerName, 'Leena Adam');
    });
  });
}
