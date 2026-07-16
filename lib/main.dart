import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _currentIndex = 0; // 0: Home, 1: Bookings, 2: Offers, 3: Support, 4: Profile
  bool _profileLoading = false;

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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return _buildBookingsView();
      case 2:
        return _buildOffersView();
      case 3:
        return _buildSupportView();
      case 4:
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
        return 'Offers & Deals';
      case 3:
        return 'Customer Support';
      case 4:
        return 'My Profile';
      default:
        return 'Turf Booking';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    leading: const Icon(Icons.local_offer),
                    title: const Text('Offers'),
                    selected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Support'),
                    selected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    selected: _currentIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 4);
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

  // 1. HOME VIEW
  Widget _buildHomeView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hello, ${widget.userName}!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ready to dominate the pitch today?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          Expanded(
            child: ListView(
              children: [
                _buildTurfCard(
                  name: 'Emerald Arena (5v5)',
                  location: 'Kharghar, Navi Mumbai',
                  price: '₹1,500 / hr',
                  rating: '4.8',
                  imageIcon: Icons.grass,
                ),
                _buildTurfCard(
                  name: 'Camp Nou Turf (7v7)',
                  location: 'Andheri West, Mumbai',
                  price: '₹2,200 / hr',
                  rating: '4.9',
                  imageIcon: Icons.stadium,
                ),
              ],
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
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(imageIcon, size: 36, color: theme.colorScheme.primary),
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

  // 3. OFFERS VIEW
  Widget _buildOffersView() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildOfferCard(
          title: 'Monsoon Special Deal',
          desc: 'Get flat 20% off on all booking slots between 12:00 PM and 04:00 PM.',
          code: 'RAINY20',
          color: theme.colorScheme.primary,
        ),
        _buildOfferCard(
          title: 'First Match Discount',
          desc: 'First time booking a turf? Enjoy ₹300 off on your very first turf slot.',
          code: 'FIRSTPLAY',
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildOfferCard({
    required String title,
    required String desc,
    required String code,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Promo code "$code" copied!')),
                    );
                  },
                  child: const Text('Copy Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. SUPPORT VIEW
  Widget _buildSupportView() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How can we help you today?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ExpansionTile(
              leading: Icon(Icons.question_answer),
              title: Text('How do I cancel my turf booking?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'You can cancel your booking up to 6 hours before the match time via the "My Bookings" page. Refunds are processed within 2-3 business days.',
                  ),
                ),
              ],
            ),
          ),
          const Card(
            child: ExpansionTile(
              leading: Icon(Icons.payment),
              title: Text('What payment methods are supported?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'We support Credit/Debit cards, UPI payments, NetBanking, and popular digital wallets.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Send us a message',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Describe your issue...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support ticket submitted successfully.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Submit Ticket'),
          ),
        ],
      ),
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
          // Elegant Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    widget.userName.substring(0, widget.userName.length > 1 ? 2 : 1).toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userEmail,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
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
          _buildProfileTile(Icons.location_city, 'City / Region', 'Mumbai, India'),
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
          child: const Icon(Icons.phone, size: 20, color: Color(0xFF10B981)),
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
