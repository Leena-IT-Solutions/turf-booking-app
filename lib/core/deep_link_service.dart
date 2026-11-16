import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/turf.dart';
import 'api_client.dart';

class DeepLinkService {
  static const String pendingQrKey = 'pending_turf_qr_code';
  static const String firstLaunchCheckedKey = 'qr_first_launch_checked';

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  /// Extract an 8-character (or numeric) turf QR code from:
  /// - https://turf.infoleena.com/t/AB12CD34
  /// - turfbooking://turf/AB12CD34
  /// - Play Install Referrer string: utm_source=qr&turf_code=AB12CD34
  /// - Clipboard deferred token: TURFBOOKING:AB12CD34
  static String? extractTurfCodeFromUri(Uri? uri) {
    if (uri == null) return null;

    // 1. Custom scheme: turfbooking://turf/AB12CD34
    if (uri.scheme.toLowerCase() == 'turfbooking') {
      if (uri.host.toLowerCase() == 'turf' && uri.pathSegments.isNotEmpty) {
        return _cleanCode(uri.pathSegments.first);
      }
      if (uri.host.isNotEmpty && uri.host.toLowerCase() != 'turf') {
        return _cleanCode(uri.host);
      }
    }

    // 2. HTTPS App Link / Universal Link: /t/{code}
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0].toLowerCase() == 't') {
      return _cleanCode(segments[1]);
    }

    // 3. Query param fallback: ?turf_code=AB12CD34
    if (uri.queryParameters.containsKey('turf_code')) {
      return _cleanCode(uri.queryParameters['turf_code']);
    }

    return null;
  }

  /// Extract a turf code from a Play Store referrer or clipboard string.
  static String? extractTurfCodeFromRawString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    // Clipboard format: TURFBOOKING:AB12CD34
    final clipMatch = RegExp(r'^TURFBOOKING:([A-Za-z0-9]{4,16})$', caseSensitive: false).firstMatch(trimmed);
    if (clipMatch != null) {
      return _cleanCode(clipMatch.group(1));
    }

    // Referrer query string: utm_source=qr&turf_code=AB12CD34
    try {
      final params = Uri.splitQueryString(trimmed);
      if (params.containsKey('turf_code')) {
        return _cleanCode(params['turf_code']);
      }
    } catch (_) {}

    // Full URL inside string
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      return extractTurfCodeFromUri(uri);
    }

    return null;
  }

  static String? _cleanCode(String? value) {
    if (value == null) return null;
    final cleaned = value.trim().toUpperCase();
    if (RegExp(r'^[A-Z0-9]{4,16}$').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }

  /// Start listening to incoming App Links / Universal Links and check first-launch deferred tokens.
  static Future<void> initialize({
    required Future<void> Function(String code) onTurfCodeDetected,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check initial deep link on cold start
    try {
      final initialUri = await _appLinks.getInitialLink();
      final initialCode = extractTurfCodeFromUri(initialUri);
      if (initialCode != null) {
        await prefs.setString(pendingQrKey, initialCode);
        await onTurfCodeDetected(initialCode);
      }
    } catch (_) {}

    // 2. Listen for deep links while the app is open in background/foreground
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen((Uri uri) async {
      final code = extractTurfCodeFromUri(uri);
      if (code != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString(pendingQrKey, code);
        await onTurfCodeDetected(code);
      }
    }, onError: (_) {});

    // 3. First-launch deferred deep-link check (clipboard token from /t/{code} landing page)
    final alreadyCheckedFirstLaunch = prefs.getBool(firstLaunchCheckedKey) ?? false;
    if (!alreadyCheckedFirstLaunch) {
      await prefs.setBool(firstLaunchCheckedKey, true);
      if (!kIsWeb && prefs.getString(pendingQrKey) == null) {
        try {
          final clipData = await Clipboard.getData(Clipboard.kTextPlain);
          final clipCode = extractTurfCodeFromRawString(clipData?.text);
          if (clipCode != null) {
            await prefs.setString(pendingQrKey, clipCode);
            // Clear the token from clipboard so it isn't reused
            await Clipboard.setData(const ClipboardData(text: ''));
            await onTurfCodeDetected(clipCode);
          }
        } catch (_) {}
      }
    } else {
      // If there's already a stored pending QR code from earlier in this session
      final stored = prefs.getString(pendingQrKey);
      if (stored != null && stored.isNotEmpty) {
        await onTurfCodeDetected(stored);
      }
    }
  }

  static Future<String?> getPendingTurfCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(pendingQrKey);
    return (code != null && code.isNotEmpty) ? code : null;
  }

  static Future<void> clearPendingTurfCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingQrKey);
  }

  /// Fetch Turf details by its 8-character QR code from GET /api/turfs/by-code/{code}.
  static Future<Turf?> fetchTurfByCode(String code, {String? token}) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) ...ApiClient.authHeaders(token),
      };
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/turfs/by-code/$code'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return Turf.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Report QR conversion attribution once the user registers or logs in.
  static Future<void> reportAttribution(String code, String token) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'desktop');
      await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/qr/attribution'),
        headers: ApiClient.authHeaders(token),
        body: jsonEncode({
          'code': code,
          'platform': platform,
        }),
      );
    } catch (_) {}
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
