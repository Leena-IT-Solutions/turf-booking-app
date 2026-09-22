import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Service managing Firebase Cloud Messaging (FCM), local notification banners,
/// device token registration, and notification tap deep-linking.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'turf_booking_notifications',
    'Turf Booking Notifications',
    description: 'Notifications for bookings, cancellations, payments, and announcements.',
    importance: Importance.high,
  );

  /// Callback when a user taps a booking-related notification
  static void Function(String bookingId)? onNavigateToBooking;

  /// Initialize Firebase Messaging and local notifications
  static Future<void> initialize() async {
    try {
      // 1. Request notification permissions (iOS & Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // 2. Initialize local notifications plugin
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              handleMessageData(data);
            } catch (_) {}
          }
        },
      );

      // Create high-importance Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 3. Foreground message listener: display heads-up banner via flutter_local_notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@drawable/ic_notification',
                color: const Color(0xFF10B981),
                largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      // 4. Background message tapped listener (app resumed from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleMessageData(message.data);
      });

      // 5. Cold start message listener (app opened from terminated state)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        handleMessageData(initialMessage.data);
      }

      // 6. Token refresh listener: re-POST rotated token to backend if user is logged in
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final prefs = await SharedPreferences.getInstance();
        final authToken = prefs.getString('access_token');
        if (authToken != null && authToken.isNotEmpty) {
          await registerTokenWithBackend(authToken, fcmToken: newToken);
        }
      });
    } catch (_) {
      // Firebase might not be initialized if google-services.json is missing during dev
    }
  }

  /// Resolve and route notification data payload
  static void handleMessageData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final bookingId = data['booking_id']?.toString();

    if (type == 'custom_notification') {
      // Custom announcements just display, no deep navigation required
      return;
    }

    if (bookingId != null && bookingId.isNotEmpty) {
      if (onNavigateToBooking != null) {
        onNavigateToBooking!(bookingId);
      } else {
        // Fallback: pop to root so user is on MainScreen
        ApiClient.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    }
  }

  /// Retrieve current device FCM token
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Register real device FCM token with backend
  static Future<void> registerTokenWithBackend(String authToken, {String? fcmToken}) async {
    try {
      final token = fcmToken ?? await getToken();
      if (token == null || token.isEmpty) return;

      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/user/device-token'),
        headers: ApiClient.authHeaders(authToken),
        body: jsonEncode({
          'device_token': token,
          'device_type': deviceType,
        }),
      );
    } catch (_) {}
  }

  /// Delete current device FCM token from backend on logout
  static Future<void> deleteTokenFromBackend(String authToken) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;

      await ApiClient.delete(
        Uri.parse('${ApiClient.baseUrl}/user/device-token'),
        headers: ApiClient.authHeaders(authToken),
        body: jsonEncode({
          'device_token': token,
        }),
      );
    } catch (_) {}
  }
}
