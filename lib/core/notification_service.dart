import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

enum NotificationRouteTarget {
  none,
  bookings,
  clientBookings,
  support,
  turfDetail,
  dashboard,
}

class NotificationRoute {
  final NotificationRouteTarget target;
  final String? bookingId;
  final int? turfId;
  final Map<String, dynamic> rawData;

  const NotificationRoute({
    required this.target,
    this.bookingId,
    this.turfId,
    this.rawData = const {},
  });
}

/// Service managing Firebase Cloud Messaging (FCM), local notification banners,
/// device token registration, and notification tap deep-linking.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void>? _initFuture;
  static Future<LocationPermission>? _locationPermissionFuture;

  /// Android notification channels so users can independently mute offers/reminders
  /// in Android OS settings without losing transactional booking alerts.
  static const List<AndroidNotificationChannel> androidChannels = [
    AndroidNotificationChannel(
      'bookings',
      'Bookings & Payments',
      description: 'Confirmations, cancellations, reschedules, refunds, and payment receipts.',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'reminders',
      'Match Reminders & Reviews',
      description: 'Upcoming match reminders, post-match review prompts, and morning digests.',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'offers',
      'Offers & Coupons',
      description: 'Promotional discounts and coupon alerts from turfs near you.',
      importance: Importance.low,
    ),
    AndroidNotificationChannel(
      'payouts',
      'Payouts & Billing',
      description: 'Payout disbursements, rejections, and commission tax invoices.',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'support',
      'Customer Support Chat',
      description: 'Replies and messages from Turf Booking Support.',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'turf_booking_notifications',
      'General Announcements',
      description: 'General platform announcements and updates.',
      importance: Importance.high,
    ),
  ];

  /// Legacy callback kept for compatibility
  static void Function(String bookingId)? onNavigateToBooking;

  static void Function(NotificationRoute route)? _tapHandler;
  static NotificationRoute? _pendingRoute;

  /// Register the active MainScreen tap router. If a cold-start notification tap
  /// arrived before MainScreen mounted, it is replayed immediately.
  static void registerTapHandler(void Function(NotificationRoute route) handler) {
    _tapHandler = handler;
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      handler(pending);
    }
  }

  static void clearTapHandler() {
    _tapHandler = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _tapHandler = null;
    _pendingRoute = null;
    onNavigateToBooking = null;
  }

  /// Pure function mapping a notification data payload to a structured destination.
  static NotificationRoute resolveRoute(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    final bookingId = data['booking_id']?.toString();
    final turfId = int.tryParse((data['turf_id'] ?? '').toString());

    if (type == 'custom_notification') {
      return NotificationRoute(target: NotificationRouteTarget.none, rawData: data);
    }

    switch (type) {
      case 'booking_created':
      case 'booking_cancelled':
      case 'booking_rescheduled':
      case 'payment_received':
      case 'match_reminder':
      case 'refund_processed':
        return NotificationRoute(
          target: NotificationRouteTarget.bookings,
          bookingId: bookingId,
          turfId: turfId,
          rawData: data,
        );

      case 'manager_booking_created':
      case 'manager_booking_cancelled':
      case 'manager_booking_rescheduled':
      case 'daily_digest':
        return NotificationRoute(
          target: NotificationRouteTarget.clientBookings,
          bookingId: bookingId,
          turfId: turfId,
          rawData: data,
        );

      case 'support_reply':
      case 'admin_support_message':
        return NotificationRoute(
          target: NotificationRouteTarget.support,
          rawData: data,
        );

      case 'review_prompt':
      case 'new_offer':
        if (turfId != null) {
          return NotificationRoute(
            target: NotificationRouteTarget.turfDetail,
            bookingId: bookingId,
            turfId: turfId,
            rawData: data,
          );
        }
        return NotificationRoute(
          target: NotificationRouteTarget.bookings,
          bookingId: bookingId,
          rawData: data,
        );

      case 'turf_verification':
      case 'payout_paid':
      case 'payout_rejected':
      case 'new_review':
      case 'trial_expiring':
      case 'commission_invoice':
      case 'admin_turf_submitted':
      case 'manual_payout_requested':
      case 'admin_payout_failed':
        return NotificationRoute(
          target: NotificationRouteTarget.dashboard,
          turfId: turfId,
          rawData: data,
        );

      default:
        if (bookingId != null && bookingId.isNotEmpty) {
          return NotificationRoute(
            target: NotificationRouteTarget.bookings,
            bookingId: bookingId,
            turfId: turfId,
            rawData: data,
          );
        }
        return NotificationRoute(target: NotificationRouteTarget.none, rawData: data);
    }
  }

  /// Resolve and route notification data payload, queueing for cold-start if needed.
  static void handleMessageData(Map<String, dynamic> data) {
    final route = resolveRoute(data);
    if (route.target == NotificationRouteTarget.none) {
      return;
    }

    if (_tapHandler != null) {
      _tapHandler!(route);
      return;
    }

    if (route.target == NotificationRouteTarget.bookings &&
        route.bookingId != null &&
        onNavigateToBooking != null) {
      onNavigateToBooking!(route.bookingId!);
      return;
    }

    // Store as pending so MainScreen executes it as soon as it mounts
    _pendingRoute = route;
  }

  /// Initialize Firebase Messaging and local notifications (idempotent)
  static Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  /// Ensures notification permission dialog has completed first, then requests
  /// location permission sequentially so Android/iOS never drops the location prompt.
  static Future<LocationPermission> ensureLocationPermission() {
    return _locationPermissionFuture ??= _doEnsureLocationPermission().whenComplete(() {
      _locationPermissionFuture = null;
    });
  }

  static Future<LocationPermission> _doEnsureLocationPermission() async {
    try {
      await initialize();

      // Wait until the app returns to the foreground (resumed) after the
      // Notification permission dialog closes so Android never drops the second prompt.
      for (int i = 0; i < 30; i++) {
        final state = WidgetsBinding.instance.lifecycleState;
        if (state == null || state == AppLifecycleState.resumed) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await Future.delayed(const Duration(milliseconds: 500));

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final sw = Stopwatch()..start();
        permission = await Geolocator.requestPermission();
        sw.stop();

        // If Android aborted the request instantaneously (< 250ms) because the
        // previous GrantPermissionsActivity was still animating closed, retry once.
        if (permission == LocationPermission.denied && sw.elapsedMilliseconds < 250) {
          await Future.delayed(const Duration(milliseconds: 700));
          permission = await Geolocator.requestPermission();
        }
      }
      return permission;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  static AndroidNotificationChannel _channelForId(String? channelId) {
    if (channelId != null && channelId.isNotEmpty) {
      for (final ch in androidChannels) {
        if (ch.id == channelId) return ch;
      }
    }
    return androidChannels.first;
  }

  static Future<void> _doInitialize() async {
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

      // Register all categorized Android notification channels
      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        for (final ch in androidChannels) {
          await androidImpl.createNotificationChannel(ch);
        }
      }

      // 3. Foreground message listener: display heads-up banner via flutter_local_notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          final requestedChannelId = message.data['android_channel_id']?.toString();
          final channel = _channelForId(requestedChannelId);

          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@drawable/ic_notification',
                color: const Color(0xFF10B981),
                largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
                importance: channel.importance,
                priority: channel.importance == Importance.low ? Priority.low : Priority.high,
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
