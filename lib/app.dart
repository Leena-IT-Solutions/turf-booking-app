import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/deep_link_service.dart';
import 'core/notification_service.dart';
import 'models/turf.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/turf_detail_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  String? _token;
  String? _userName;
  String? _userEmail;
  String? _userMobile;
  String? _pendingTurfCode;
  Turf? _pendingTurf;

  @override
  void initState() {
    super.initState();
    ApiClient.onUnauthorized = _handleUnauthorized;
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Sequentially request Notification and Location permissions so Android/iOS
    // never drops the Location permission dialog due to overlapping dialogs.
    NotificationService.ensureLocationPermission();

    // 2. Unlock UI and initialize deep links concurrently
    await _checkLoginStatus();
    await DeepLinkService.initialize(onTurfCodeDetected: _handleTurfQrCode);
  }

  Future<void> _handleTurfQrCode(String code) async {
    if (!mounted) return;
    setState(() {
      _pendingTurfCode = code;
    });

    final turf = await DeepLinkService.fetchTurfByCode(code, token: _token);
    if (!mounted || turf == null) return;

    setState(() {
      _pendingTurf = turf;
    });

    // If user is already logged in, navigate straight to TurfDetailScreen
    if (_token != null && _token!.isNotEmpty) {
      await DeepLinkService.clearPendingTurfCode();
      await DeepLinkService.reportAttribution(code, _token!);
      setState(() {
        _pendingTurfCode = null;
        _pendingTurf = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = ApiClient.navigatorKey.currentState;
        if (nav != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => TurfDetailScreen(turf: turf, token: _token),
            ),
          );
        }
      });
    }
  }

  void _handleUnauthorized() {
    _onLogout(isUnauthorized: true);
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _token = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Immediately unlock the UI using cached credentials so startup is instant,
      // then validate and refresh the user profile against the backend.
      if (mounted) {
        setState(() {
          _token = token;
          _userName = prefs.getString('user_name');
          _userEmail = prefs.getString('user_email');
          _userMobile = prefs.getString('user_mobile');
          _isLoading = false;
        });
      }

      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/user'),
        headers: ApiClient.authHeaders(token),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await prefs.clear();
        if (mounted) {
          setState(() {
            _token = null;
            _userName = null;
            _userEmail = null;
            _userMobile = null;
            _isLoading = false;
          });
        }
        return;
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data is Map<String, dynamic> ? data : null;
        if (user != null) {
          if (user['name'] != null) await prefs.setString('user_name', user['name']);
          if (user['email'] != null) await prefs.setString('user_email', user['email']);
          if (user['mobile'] != null) await prefs.setString('user_mobile', user['mobile']);
          if (user['roles'] != null) {
            final roles = List<String>.from((user['roles'] as List).map((r) => r is Map ? (r['name'] ?? '') : r.toString()));
            await prefs.setStringList('user_roles', roles);
          }
          if (user['manageable_turf_ids'] != null) {
            final manageable = List<dynamic>.from(user['manageable_turf_ids'] as List).map((t) => t.toString()).toList();
            await prefs.setStringList('manageable_turf_ids', manageable);
          }
        }
      }

      if (mounted) {
        setState(() {
          _token = prefs.getString('access_token');
          _userName = prefs.getString('user_name');
          _userEmail = prefs.getString('user_email');
          _userMobile = prefs.getString('user_mobile');
          _isLoading = false;
        });

        if (_token != null && _token!.isNotEmpty) {
          _registerDeviceToken(_token!);
        }
      }
    } catch (_) {
      // Never leave the app stuck on the loading spinner if SharedPreferences or network throws
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onLoginSuccess(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setString('user_mobile', user['mobile'] ?? '');
    final roles = List<String>.from(user['roles'] ?? []);
    await prefs.setStringList('user_roles', roles);
    final manageable = List<dynamic>.from(user['manageable_turf_ids'] ?? []).map((t) => t.toString()).toList();
    await prefs.setStringList('manageable_turf_ids', manageable);

    setState(() {
      _token = token;
      _userName = user['name'];
      _userEmail = user['email'];
      _userMobile = user['mobile'];
    });

    _registerDeviceToken(token);

    // If the user scanned a Turf QR Code before registering/logging in, open that Turf immediately
    final pendingCode = _pendingTurfCode ?? await DeepLinkService.getPendingTurfCode();
    if (pendingCode != null && pendingCode.isNotEmpty) {
      final turf = _pendingTurf ?? await DeepLinkService.fetchTurfByCode(pendingCode, token: token);
      await DeepLinkService.clearPendingTurfCode();
      await DeepLinkService.reportAttribution(pendingCode, token);
      if (mounted) {
        setState(() {
          _pendingTurfCode = null;
          _pendingTurf = null;
        });
      }
      if (turf != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = ApiClient.navigatorKey.currentState;
          if (nav != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => TurfDetailScreen(turf: turf, token: token),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    await NotificationService.registerTokenWithBackend(token);
  }

  void _onLogout({bool isUnauthorized = false}) async {
    if (_token == null && !_isLoading) return;

    final prefs = await SharedPreferences.getInstance();
    final token = _token ?? prefs.getString('access_token');

    if (!isUnauthorized && token != null && token.isNotEmpty) {
      try {
        await NotificationService.deleteTokenFromBackend(token);
        ApiClient.post(
          Uri.parse('${ApiClient.baseUrl}/logout'),
          headers: ApiClient.authHeaders(token),
        );
      } catch (_) {}
    }

    await prefs.clear();

    ApiClient.navigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (mounted) {
      setState(() {
        _token = null;
        _userName = null;
        _userEmail = null;
        _userMobile = null;
      });

      if (isUnauthorized) {
        final ctx = ApiClient.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Session expired or unauthorized. Please log in again.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _onProfileUpdated(String name, String email, String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_mobile', mobile);

    setState(() {
      _userName = name;
      _userEmail = email;
      _userMobile = mobile;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: ApiClient.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Turf Booking',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF0F172A),
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAF5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFFF8FAFC),
          surface: const Color(0xFF1E2022),
          onSurface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFF121315),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2022),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      // On Android, the system navigation bar defaults to a translucent scrim over app
      // content in edge-to-edge mode -- this is what makes buttons/text near the bottom of
      // the screen look "washed out" even when they're correctly positioned above it via
      // SafeArea/MediaQuery padding. Pinning it to an opaque color matching the active
      // theme removes that scrim entirely, independent of any padding math.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktopOrTablet = screenWidth > 600;

        Widget appWidget = child!;
        if (isDesktopOrTablet) {
          appWidget = Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? const Color(0xFF121315) : const Color(0xFFF9FAF5),
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: appWidget,
        );
      },
      home: _token != null
          ? MainScreen(
              userName: _userName ?? 'Customer',
              userEmail: _userEmail ?? '',
              userMobile: _userMobile ?? '',
              token: _token!,
              onLogout: () => _onLogout(isUnauthorized: false),
              onProfileUpdated: _onProfileUpdated,
            )
          : AuthScreen(
              onLoginSuccess: _onLoginSuccess,
              startOnRegister: _pendingTurfCode != null,
              pendingTurf: _pendingTurf,
            ),
    );
  }
}
