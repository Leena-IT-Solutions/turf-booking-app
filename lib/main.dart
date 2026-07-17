import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
void main() {
  runApp(const MyApp());
}

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

    setState(() {
      _token = token;
      _userName = user['name'];
      _userEmail = user['email'];
      _userMobile = user['mobile'];
    });
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_mobile');

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
          centerTitle: true,
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
          centerTitle: true,
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

// ---------------------------------------------------------------------------
// AUTH SCREEN (LOGIN, REGISTER, FORGOT PASSWORD FLOWS)
// ---------------------------------------------------------------------------
enum AuthState { login, register, forgotRequest, forgotVerify, forgotReset }

class AuthScreen extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthState _state = AuthState.login;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final String _baseUrl = 'https://turf.infoleena.com/api';

  // Form Keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _forgotRequestFormKey = GlobalKey<FormState>();
  final _forgotVerifyFormKey = GlobalKey<FormState>();
  final _forgotResetFormKey = GlobalKey<FormState>();

  // Text Controllers
  final _loginInputController = TextEditingController(); // Mobile or Email
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _forgotEmailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  // --- API CALLS ---

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': _loginInputController.text.trim(),
          'password': _loginPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['access_token'];
        final user = data['user'] as Map<String, dynamic>;
        final roles = List<String>.from(user['roles'] ?? []);

        if (roles.contains('customer')) {
          widget.onLoginSuccess(token, user);
          _showSuccess('Welcome back, ${user['name']}!');
        } else {
          _showError('Access denied. Only customers can log in.');
        }
      } else {
        _showError(data['message'] ?? 'Login failed. Please check credentials.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _regNameController.text.trim(),
          'email': _regEmailController.text.trim(),
          'mobile': _regMobileController.text.trim(),
          'password': _regPasswordController.text,
          'password_confirmation': _regConfirmPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final token = data['access_token'];
        final user = data['user'] as Map<String, dynamic>;
        widget.onLoginSuccess(token, user);
        _showSuccess('Registration successful! Welcome, ${user['name']}!');
      } else {
        _showError(data['message'] ?? 'Registration failed.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotRequest() async {
    if (!_forgotRequestFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _forgotEmailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Automatically prefill OTP in development for convenience
        final otpCode = data['otp'] ?? '';
        if (otpCode.isNotEmpty) {
          _otpController.text = otpCode;
          _showSuccess('OTP Sent! code "$otpCode" has been generated for testing.');
        } else {
          _showSuccess('OTP Sent! Please check your email.');
        }
        setState(() => _state = AuthState.forgotVerify);
      } else {
        _showError(data['message'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!_forgotVerifyFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _forgotEmailController.text.trim(),
          'otp': _otpController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('OTP verified successfully.');
        setState(() => _state = AuthState.forgotReset);
      } else {
        _showError(data['message'] ?? 'Invalid OTP code.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_forgotResetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _forgotEmailController.text.trim(),
          'otp': _otpController.text.trim(),
          'password': _newPasswordController.text,
          'password_confirmation': _confirmNewPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('Password reset successfully. Please log in.');
        _loginInputController.text = _forgotEmailController.text;
        _loginPasswordController.clear();
        setState(() => _state = AuthState.login);
      } else {
        _showError(data['message'] ?? 'Password reset failed.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDING ---

  Widget _buildLogoHeader() {
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Image.asset(
            'assets/logo/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.sports_soccer,
                size: 56,
                color: Color(0xFF10B981),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Turf Booking',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogoHeader(),
                const SizedBox(height: 32),
                if (_state == AuthState.login) _buildLoginForm(theme, isDark),
                if (_state == AuthState.register) _buildRegisterForm(theme, isDark),
                if (_state == AuthState.forgotRequest) _buildForgotRequestForm(theme, isDark),
                if (_state == AuthState.forgotVerify) _buildForgotVerifyForm(theme, isDark),
                if (_state == AuthState.forgotReset) _buildForgotResetForm(theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // LOGIN FORM
  Widget _buildLoginForm(ThemeData theme, bool isDark) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your email or mobile and password to continue',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _loginInputController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email or Mobile Number',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email or mobile' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Please enter password' : null,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _state = AuthState.forgotRequest),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Don\'t have an account? ', style: TextStyle(color: Colors.grey[600])),
              GestureDetector(
                onTap: () => setState(() => _state = AuthState.register),
                child: Text(
                  'Sign Up',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // REGISTER FORM
  Widget _buildRegisterForm(ThemeData theme, bool isDark) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Join us to book your favorite turf slots quickly',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _regNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regMobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter mobile number' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm your password';
              if (value != _regPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
              GestureDetector(
                onTap: () => setState(() => _state = AuthState.login),
                child: Text(
                  'Sign In',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FORGOT REQUEST FORM (Enter Email)
  Widget _buildForgotRequestForm(ThemeData theme, bool isDark) {
    return Form(
      key: _forgotRequestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot Password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your registered email address to receive an OTP',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _forgotEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleForgotRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text('Send OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => setState(() => _state = AuthState.login),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  // FORGOT VERIFY FORM (Enter OTP)
  Widget _buildForgotVerifyForm(ThemeData theme, bool isDark) {
    return Form(
      key: _forgotVerifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Verify OTP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the 6-digit verification code sent to ${_forgotEmailController.text}',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8.0),
            decoration: const InputDecoration(
              counterText: '',
              labelText: '6-Digit OTP',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().length != 6 ? 'Please enter valid 6-digit OTP' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _state = AuthState.forgotRequest),
                child: const Text('Resend OTP'),
              ),
              TextButton(
                onPressed: () => setState(() => _state = AuthState.login),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FORGOT RESET FORM (Enter New Password)
  Widget _buildForgotResetForm(ThemeData theme, bool isDark) {
    return Form(
      key: _forgotResetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your new password to complete the reset process',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmNewPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm your password';
              if (value != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN DASHBOARD LAYOUT (ACCESSIBLE POST-LOGIN)
// ---------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userMobile;
  final String token;
  final VoidCallback onLogout;
  final Function(String, String, String) onProfileUpdated;

  const MainScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userMobile,
    required this.token,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 0: Home, 1: Bookings, 2: Support, 3: Profile
  bool _profileLoading = false;

  List<dynamic> _supportMessages = [];
  bool _supportLoading = false;
  final TextEditingController _supportMessageController = TextEditingController();
  final ScrollController _supportScrollController = ScrollController();
  final FocusNode _supportFocusNode = FocusNode();
  Timer? _supportTimer;
  bool _showChatWindow = false;
  List<dynamic> _sliderImages = [];
  bool _sliderLoading = false;
  List<dynamic> _turfs = [];
  bool _turfsLoading = false;
  PageController? _sliderPageController;
  Timer? _sliderTimer;
  int _sliderCurrentPage = 0;
  String _selectedCity = 'Mumbai';
  bool _isLocating = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<Map<String, dynamic>> _suggestions = [];
  bool _suggestionsLoading = false;
  Timer? _debounceTimer;
  String? _googleMapsApiKey;

  final String _baseUrl = 'https://turf.infoleena.com/api';

  final List<Map<String, String>> _bookings = [
    {
      'turf': 'Emerald Arena (5v5)',
      'date': 'July 20, 2026',
      'time': '06:00 PM - 07:00 PM',
      'status': 'Confirmed',
      'price': '₹1,500',
    },
    {
      'turf': 'Camp Nou Turf (7v7)',
      'date': 'July 24, 2026',
      'time': '08:00 PM - 09:00 PM',
      'status': 'Pending',
      'price': '₹2,200',
    },
  ];

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF10B981)),
    );
  }

  @override
  void initState() {
    super.initState();
    _sliderPageController = PageController(initialPage: 0);
    _fetchSliderImages();
    _fetchAppConfig();
    _getCurrentLocation();
    _fetchTurfs();
  }

  void _startSliderTimer() {
    _sliderTimer?.cancel();
    if (_sliderImages.isEmpty) return;
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_sliderPageController != null && _sliderPageController!.hasClients) {
        int nextPage = _sliderCurrentPage + 1;
        if (nextPage >= _sliderImages.length) {
          nextPage = 0;
        }
        _sliderPageController!.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchSliderImages() async {
    if (mounted) setState(() => _sliderLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/slider-images'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _sliderImages = data;
            _sliderLoading = false;
          });
          _startSliderTimer();
        }
      } else {
        if (mounted) setState(() => _sliderLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _sliderLoading = false);
    }
  }

  Future<void> _fetchTurfs() async {
    if (mounted) setState(() => _turfsLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/turfs'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _turfs = data;
            _turfsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _turfsLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _turfsLoading = false);
    }
  }

  String _capitalizeCity(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _fetchAppConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/config'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiKey = data['google_maps_api_key'] as String?;
        if (apiKey != null && apiKey.isNotEmpty) {
          setState(() {
            _googleMapsApiKey = apiKey;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch App Config: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLocating = true;
      });
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _selectedCity = 'Mumbai';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _selectedCity = 'Mumbai';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _selectedCity = 'Mumbai';
          });
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (timeoutOrError) {
        // Fallback to last known position if current position times out or errors
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          setState(() {
            _selectedCity = 'Mumbai';
            _isLocating = false;
          });
        }
        return;
      }

      debugPrint('Geolocation success: Lat: ${position.latitude}, Lng: ${position.longitude}');

      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        debugPrint('Geocoding place details: locality=${place.locality}, subAdmin=${place.subAdministrativeArea}, admin=${place.administrativeArea}');
        String? city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;
        if (mounted) {
          setState(() {
            _selectedCity = _capitalizeCity((city != null && city.isNotEmpty) ? city : 'Mumbai');
            _selectedLatitude = position!.latitude;
            _selectedLongitude = position.longitude;
            _isLocating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedCity = 'Mumbai';
            _selectedLatitude = position!.latitude;
            _selectedLongitude = position.longitude;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Geolocation error occurred: $e');
      if (mounted) {
        setState(() {
          _selectedCity = 'Mumbai';
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _selectCityAndResolveCoordinates(String cityName) async {
    if (mounted) {
      setState(() {
        _selectedCity = _capitalizeCity(cityName);
        _isLocating = true;
      });
    }
    try {
      List<Location> locations = await Geocoding().locationFromAddress(cityName);
      if (locations.isNotEmpty) {
        Location loc = locations[0];
        debugPrint('Forward geocoding success for $cityName: Lat: ${loc.latitude}, Lng: ${loc.longitude}');
        if (mounted) {
          setState(() {
            _selectedLatitude = loc.latitude;
            _selectedLongitude = loc.longitude;
            _isLocating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedLatitude = null;
            _selectedLongitude = null;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Forward geocoding error: $e');
      if (mounted) {
        setState(() {
          _selectedLatitude = null;
          _selectedLongitude = null;
          _isLocating = false;
        });
      }
    }
  }

  void _onSearchTextChanged(String text, BuildContext dialogContext, StateSetter setDialogState) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (text.trim().isEmpty) {
      if (dialogContext.mounted) {
        setDialogState(() {
          _suggestions = [];
          _suggestionsLoading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        _suggestionsLoading = true;
      });

      try {
        // Appending ', India' to force geocoding suggestions to be biased/located in India
        List<Location> locations = await Geocoding().locationFromAddress("$text, India");
        List<Map<String, dynamic>> resolvedPlaces = [];
        final Set<String> seenDisplayNames = {};
        
        int limit = locations.length > 6 ? 6 : locations.length;
        for (int i = 0; i < limit; i++) {
          if (!dialogContext.mounted) return;
          Location loc = locations[i];
          try {
            List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
              loc.latitude,
              loc.longitude,
            );
            if (placemarks.isNotEmpty) {
              Placemark pm = placemarks[0];
              
              // Validate that the returned placemark is in India
              final isIndia = (pm.country?.toLowerCase() == 'india' || pm.isoCountryCode?.toLowerCase() == 'in');
              if (!isIndia) continue;
              
              final Set<String> uniqueParts = {};
              if (pm.subLocality != null && pm.subLocality!.isNotEmpty) uniqueParts.add(pm.subLocality!);
              if (pm.locality != null && pm.locality!.isNotEmpty) uniqueParts.add(pm.locality!);
              if (pm.subAdministrativeArea != null && pm.subAdministrativeArea!.isNotEmpty) uniqueParts.add(pm.subAdministrativeArea!);
              if (pm.administrativeArea != null && pm.administrativeArea!.isNotEmpty) uniqueParts.add(pm.administrativeArea!);
              
              String displayName = uniqueParts.isNotEmpty ? uniqueParts.join(', ') : text;
              displayName = _capitalizeCity(displayName);
              
              if (seenDisplayNames.contains(displayName.toLowerCase())) continue;
              seenDisplayNames.add(displayName.toLowerCase());
              
              String city = pm.locality ?? pm.subLocality ?? pm.name ?? text;
              
              resolvedPlaces.add({
                'name': displayName,
                'city': city,
                'lat': loc.latitude,
                'lng': loc.longitude,
              });
            }
          } catch (e) {
            // Ignore error for individual placemark resolution
          }
        }

        if (dialogContext.mounted) {
          setDialogState(() {
            _suggestions = resolvedPlaces;
            _suggestionsLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Suggestions error: $e');
        if (dialogContext.mounted) {
          setDialogState(() {
            _suggestions = [];
            _suggestionsLoading = false;
          });
        }
      }
    });
  }

  void _showCityPickerDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<String> popularCities = [
      'Mumbai',
      'Navi Mumbai',
      'Thane',
      'Pune',
      'Delhi',
      'Bangalore',
      'Hyderabad',
      'Chennai'
    ];
    final Map<String, String> cityCoordinates = {
      'Mumbai': '19.0760° N, 72.8777° E',
      'Navi Mumbai': '19.0330° N, 73.0297° E',
      'Thane': '19.2183° N, 72.9781° E',
      'Pune': '18.5204° N, 73.8567° E',
      'Delhi': '28.6139° N, 77.2090° E',
      'Bangalore': '12.9716° N, 77.5946° E',
      'Hyderabad': '17.3850° N, 78.4867° E',
      'Chennai': '13.0827° N, 80.2707° E'
    };
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _debounceTimer?.cancel();
          },
          child: StatefulBuilder(
            builder: (context, setDialogState) {
            final filteredCities = popularCities
                .where((city) => city.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E2022) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_selectedLatitude != null && _selectedLongitude != null) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () {
                                  final coords = '${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}';
                                  Clipboard.setData(ClipboardData(text: coords));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied coordinates: $coords'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  '${_selectedLatitude!.toStringAsFixed(4)}°, ${_selectedLongitude!.toStringAsFixed(4)}°',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search city...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: isDark ? const Color(0xFF0F1011) : Colors.grey[100],
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                        _onSearchTextChanged(val, context, setDialogState);
                      },
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _selectCityAndResolveCoordinates(val.trim());
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Detect Location & Set on Map Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _getCurrentLocation();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              Navigator.pop(context);
                              debugPrint('Launching map picker. Configured key: $_googleMapsApiKey');
                              // Launch Map Picker Screen
                              final LatLng? result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude: _selectedLatitude ?? 19.0760,
                                    initialLongitude: _selectedLongitude ?? 72.8777,
                                  ),
                                ),
                              );
                              if (result != null) {
                                // Reverse geocode the picked coordinate and update state
                                if (mounted) {
                                  setState(() {
                                    _isLocating = true;
                                  });
                                }
                                try {
                                  List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
                                    result.latitude,
                                    result.longitude,
                                  );
                                  String city = 'Mumbai';
                                  if (placemarks.isNotEmpty) {
                                    final pm = placemarks[0];
                                    city = pm.locality ?? pm.subLocality ?? pm.name ?? 'Mumbai';
                                    city = _capitalizeCity(city);
                                  }
                                  
                                  // Save selected coordinates & city
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('selected_city', city);
                                  await prefs.setDouble('selected_latitude', result.latitude);
                                  await prefs.setDouble('selected_longitude', result.longitude);
                                  
                                  if (mounted) {
                                    setState(() {
                                      _selectedCity = city;
                                      _selectedLatitude = result.latitude;
                                      _selectedLongitude = result.longitude;
                                      _isLocating = false;
                                    });
                                    _showSuccess('Location updated to $city');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _isLocating = false;
                                    });
                                  }
                                  _showError('Failed to resolve address for selected location.');
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.map_rounded,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Set on Map',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.trim().isEmpty ? 'Popular Cities' : 'Suggestions',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (searchQuery.trim().isEmpty) ...[
                              ...filteredCities.map((city) {
                                final isSelected = city == _selectedCity;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(
                                    city,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    cityCoordinates[city] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
                                      : null,
                                  onTap: () {
                                    _selectCityAndResolveCoordinates(city);
                                    Navigator.pop(context);
                                  },
                                );
                              })
                            ] else ...[
                              if (_suggestionsLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else if (_suggestions.isEmpty)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  leading: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 20),
                                  title: Text(
                                    'Select "${searchQuery.trim()}"',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () {
                                    _selectCityAndResolveCoordinates(searchQuery.trim());
                                    Navigator.pop(context);
                                  },
                                )
                              else
                                ..._suggestions.map((suggestion) {
                                  final name = suggestion['name'] as String;
                                  final city = suggestion['city'] as String;
                                  final lat = suggestion['lat'] as double;
                                  final lng = suggestion['lng'] as double;
                                  
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 20),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      '${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                    onTap: () {
                                      if (mounted) {
                                        setState(() {
                                          _selectedCity = _capitalizeCity(city);
                                          _selectedLatitude = lat;
                                          _selectedLongitude = lng;
                                        });
                                      }
                                      Navigator.pop(context);
                                    },
                                  );
                                }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
    );
  }

  // --- API OPERATIONS ---

  Future<void> _handleUpdateProfile(String name, String email, String mobile) async {
    setState(() => _profileLoading = true);

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'mobile': mobile.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        widget.onProfileUpdated(name, email, mobile);
        _showSuccess('Profile details updated successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _handleChangePassword(String currentPassword, String newPassword, String confirmPassword) async {
    setState(() => _profileLoading = true);

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('Password updated successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to change password.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _profileLoading = true);

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        widget.onLogout();
        _showSuccess('Your account has been deleted successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to delete account.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  // --- ACTIONS SHEETS / DIALOGS ---

  void _showEditProfileBottomSheet() {
    final nameController = TextEditingController(text: widget.userName);
    final emailController = TextEditingController(text: widget.userEmail);
    final mobileController = TextEditingController(text: widget.userMobile);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Personal Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter mobile number' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        _handleUpdateProfile(
                          nameController.text,
                          emailController.text,
                          mobileController.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordBottomSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter current password' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm your new password';
                      if (value != newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        _handleChangePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                          confirmPasswordController.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text(
            'WARNING: Deleting your account will permanently remove all bookings, offers, and details from our system. This action cannot be undone.\n\nAre you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleDeleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout of Turf Booking?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _supportTimer?.cancel();
    _supportMessageController.dispose();
    _supportScrollController.dispose();
    _supportFocusNode.dispose();
    _sliderTimer?.cancel();
    _sliderPageController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_supportScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _supportScrollController.animateTo(
          _supportScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _fetchSupportMessages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _supportLoading = true);
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/support/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _supportMessages = data;
          _supportLoading = false;
        });
        _scrollToBottom();
      } else {
        if (showLoading) setState(() => _supportLoading = false);
      }
    } catch (e) {
      if (showLoading) setState(() => _supportLoading = false);
    }
  }

  Future<void> _sendSupportMessage() async {
    final text = _supportMessageController.text.trim();
    if (text.isEmpty) return;

    _supportMessageController.clear();
    _supportFocusNode.requestFocus();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/support/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 201) {
        final newMsg = jsonDecode(response.body);
        setState(() {
          _supportMessages.add(newMsg);
        });
        _scrollToBottom();
      } else {
        _showError('Failed to send message.');
      }
    } catch (e) {
      _showError('Network error. Failed to send message.');
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return _buildBookingsView();
      case 2:
        return _buildSupportView();
      case 3:
        return _buildProfileView();
      default:
        return _buildHomeView();
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Turf Booking';
      case 1:
        return 'My Bookings';
      case 2:
        return 'Customer Support';
      case 3:
        return 'My Profile';
      default:
        return 'Turf Booking';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not on support tab or chat window closed, cancel support timer
    if ((_currentIndex != 2 || !_showChatWindow) && _supportTimer != null) {
      _supportTimer?.cancel();
      _supportTimer = null;
    }

    final theme = Theme.of(context);
    final isSubPage = _currentIndex > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                widget.userName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(widget.userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E2022)
                    : Colors.white,
                child: Text(
                  widget.userName.substring(0, widget.userName.length > 1 ? 2 : 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Home'),
                    selected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('My Bookings'),
                    selected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Support'),
                    selected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    selected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_profileLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !isSubPage
          ? BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: Colors.grey,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month),
                  label: 'My Bookings',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildSliderWidget() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_sliderLoading && _sliderImages.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2022) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_sliderImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _sliderPageController,
              onPageChanged: (index) {
                setState(() {
                  _sliderCurrentPage = index;
                });
              },
              itemCount: _sliderImages.length,
              itemBuilder: (context, index) {
                final slide = _sliderImages[index];
                return GestureDetector(
                  onTap: () {
                    final linkUrl = slide['link_url'];
                    if (linkUrl != null && linkUrl.toString().isNotEmpty) {
                      // Custom click action
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        slide['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.broken_image_rounded, size: 48),
                          );
                        },
                      ),
                      // Gradient overlay
                      if (slide['title'] != null && slide['title'].toString().isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              slide['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Indicators
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sliderImages.length, (index) {
                final isActive = _sliderCurrentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 5,
                  width: isActive ? 15 : 5,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 1. HOME VIEW
  Widget _buildHomeView() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: _showCityPickerDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'YOUR LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _isLocating ? 'Locating...' : _selectedCity,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  widget.userName.isNotEmpty ? widget.userName.substring(0, 1).toUpperCase() : 'U',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 16:9 Image Slider
          _buildSliderWidget(),
          const SizedBox(height: 24),

          // Featured Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Turfs near you',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Text(
                'See All',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Turf List
          Expanded(
            child: _turfsLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _turfs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sports_soccer,
                              size: 48,
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No approved turfs found',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchTurfs,
                        child: ListView.builder(
                          itemCount: _turfs.length,
                          itemBuilder: (context, index) {
                            final turf = _turfs[index];
                            return _buildTurfCard(
                              name: turf['name'] ?? '',
                              location: '${turf['location_name'] ?? ''}, ${turf['location_address'] ?? ''}',
                              price: turf['price_text'] ?? '₹1,000 / hr',
                              rating: turf['rating'] ?? '4.8',
                              imageIcon: turf['type'] == 'Synthetic'
                                  ? Icons.grass
                                  : Icons.stadium,
                              imageUrl: turf['image_url'],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurfCard({
    required String name,
    required String location,
    required String price,
    required String rating,
    required IconData imageIcon,
    String? imageUrl,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(imageIcon, size: 32, color: theme.colorScheme.primary),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(imageIcon, size: 32, color: theme.colorScheme.primary),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. BOOKINGS VIEW
  Widget _buildBookingsView() {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final b = _bookings[index];
        final isConfirmed = b['status'] == 'Confirmed';
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      b['turf']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isConfirmed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        b['status']!,
                        style: TextStyle(
                          color: isConfirmed ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(b['date']!, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(b['time']!, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price Paid',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      b['price']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSupportInfoView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Icon illustration
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent,
                size: 72,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'How can we help you?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get in touch with us using one of the options below.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),

          // Email Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'turf@infoleena.com',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chat Card
          InkWell(
            onTap: () {
              setState(() {
                _showChatWindow = true;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Chat Support',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Chat with our team in real-time',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_showChatWindow) {
      return _buildSupportInfoView();
    }

    // Trigger timer/fetch
    if (_supportTimer == null && !_supportLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchSupportMessages();
        _supportTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          _fetchSupportMessages(showLoading: false);
        });
      });
    }

    return Column(
      children: [
        // Back to Support Menu Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2022) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showChatWindow = false;
                  });
                  _supportTimer?.cancel();
                  _supportTimer = null;
                },
              ),
              const Text(
                'Live Chat Support',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        // Message Stream
        Expanded(
          child: _supportLoading
              ? const Center(child: CircularProgressIndicator())
              : _supportMessages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '💬',
                              style: TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send a message below to start a conversation with our support team.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _supportScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _supportMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _supportMessages[index];
                        final isMe = msg['sender_id'] == msg['user_id'];
                        final createdStr = msg['created_at'] != null 
                            ? DateTime.parse(msg['created_at']).toLocal() 
                            : DateTime.now();
                        // Format time manually
                        final timeStr = "${createdStr.hour.toString().padLeft(2, '0')}:${createdStr.minute.toString().padLeft(2, '0')}";

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? theme.colorScheme.primary
                                  : isDark
                                      ? const Color(0xFF1E2022)
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                              ),
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['message'] ?? '',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : isDark
                                            ? Colors.white
                                            : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey[500],
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2022) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supportMessageController,
                    focusNode: _supportFocusNode,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: isDark ? const Color(0xFF0F1011) : Colors.grey[100],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendSupportMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendSupportMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. PROFILE VIEW
  Widget _buildProfileView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Stunning Premium Profile Card with overlapping cover banner
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 8),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Section with Banner & Avatar Stack
                SizedBox(
                  height: 145,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Banner
                      Container(
                        height: 95,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withAlpha(200),
                              theme.colorScheme.secondary.withAlpha(200),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Decorative circle
                      Positioned(
                        right: -10,
                        top: -10,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withAlpha(25),
                        ),
                      ),
                      // Avatar positioned overlapping the banner
                      Positioned(
                        top: 45,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                widget.userName.substring(0, widget.userName.length > 1 ? 2 : 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rest of card details
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                  child: Column(
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userEmail,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Personal Information Section
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'PERSONAL DETAILS',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          _buildProfileTile(Icons.phone, 'Mobile Number', widget.userMobile.isNotEmpty ? widget.userMobile : 'Not Provided'),
          _buildProfileTile(Icons.email, 'Email Address', widget.userEmail),
          const SizedBox(height: 24),
          // Settings and Actions Section
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Edit Profile details action
          _buildSettingsTile(
            icon: Icons.edit_note,
            title: 'Edit Personal Details',
            subtitle: 'Update your name, email, and mobile',
            iconColor: theme.colorScheme.primary,
            onTap: _showEditProfileBottomSheet,
          ),
          // Change password action
          _buildSettingsTile(
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Reset or secure your password details',
            iconColor: Colors.amber[700]!,
            onTap: _showChangePasswordBottomSheet,
          ),
          // Delete account action
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete My Account',
            subtitle: 'Permanently close and delete your credentials',
            iconColor: Colors.red,
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF10B981)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;

  const MapPickerScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final locations = await Geocoding().locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newLatLng = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedLocation = newLatLng;
        });
        _mapController.move(newLatLng, 15.0);
      } else {
        _showError('No locations found for "$query"');
      }
    } catch (e) {
      _showError('Location not found. Please try a different query.');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_rounded),
            onPressed: () {
              Navigator.pop(context, _selectedLocation);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.infoleena.turf.booking',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_on,
                      size: 45,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                   children: [
                     Expanded(
                       child: TextField(
                         controller: _searchController,
                         decoration: const InputDecoration(
                           hintText: 'Search location...',
                           border: InputBorder.none,
                         ),
                         onSubmitted: (_) => _searchAddress(),
                       ),
                     ),
                     if (_isSearching)
                       const Padding(
                         padding: EdgeInsets.symmetric(horizontal: 8.0),
                         child: SizedBox(
                           width: 20,
                           height: 20,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         ),
                       )
                     else
                       IconButton(
                         icon: const Icon(Icons.search),
                         onPressed: _searchAddress,
                       ),
                   ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text(
                'Confirm Selected Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
