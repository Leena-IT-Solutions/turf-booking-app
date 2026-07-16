import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turf_booking/main.dart';

void main() {
  testWidgets('Navigation and UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is present.
    expect(find.text('Turf Booking'), findsOneWidget);

    // Verify that the Home page dashboard content is loaded.
    expect(find.text('Hello, Sandeep Rathod!'), findsOneWidget);

    // Tap the 'Book New Slot' floating action button and trigger a frame.
    await tester.tap(find.byIcon(Icons.add_task));
    await tester.pump();

    // Verify that the bottom navigation bar has the primary items.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Bookings'), findsOneWidget);
  });
}
