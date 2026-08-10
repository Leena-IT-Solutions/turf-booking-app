import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('access_token');
      _userName = prefs.getString('user_name');
      _userEmail = prefs.getString('user_email');
      _userMobile = prefs.getString('user_mobile');
      _isLoading = false;
    });
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
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      final deviceToken = 'fcm_device_token_${DateTime.now().millisecondsSinceEpoch}';
      await http.post(
        Uri.parse('${ApiClient.baseUrl}/user/device-token'),
        headers: ApiClient.authHeaders(token),
        body: jsonEncode({
          'device_token': deviceToken,
          'device_type': 'android',
        }),
      );
    } catch (_) {}
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _token = null;
      _userName = null;
      _userEmail = null;
      _userMobile = null;
    });
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
      home: _token != null
          ? MainScreen(
              userName: _userName ?? 'Customer',
              userEmail: _userEmail ?? '',
              userMobile: _userMobile ?? '',
              token: _token!,
              onLogout: _onLogout,
              onProfileUpdated: _onProfileUpdated,
            )
          : AuthScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}
