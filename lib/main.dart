import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';

export 'app.dart' show MyApp;

/// Top-level background message handler annotated for VM entry point.
/// Must be top-level, not nested in a class or closure.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    // If google-services.json / GoogleService-Info.plist is not yet added,
    // prevent app startup crash while awaiting manual credential placement.
  }

  runApp(const MyApp());
}
