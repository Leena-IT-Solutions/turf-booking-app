import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:turf_booking/main.dart';

void main() {
  testWidgets('Authentication and UI smoke test', (WidgetTester tester) async {
    // Set initial mock values for SharedPreferences.
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for the asynchronous SharedPreferences check to complete.
    await tester.pumpAndSettle();

    // Verify that the title is present on the Auth/Login screen.
    expect(find.text('Turf Booking'), findsOneWidget);

    // Verify that the Sign In form elements are loaded.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email or Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
