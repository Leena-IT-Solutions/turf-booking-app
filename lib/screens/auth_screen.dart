import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/snackbar_helper.dart';

enum AuthState { login, regMobile, regOtp, regProfile, regPassword, forgotRequest, forgotVerify, forgotReset }

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


  // Form Keys
  final _loginFormKey = GlobalKey<FormState>();
  final _regMobileFormKey = GlobalKey<FormState>();
  final _regOtpFormKey = GlobalKey<FormState>();
  final _regProfileFormKey = GlobalKey<FormState>();
  final _regPasswordFormKey = GlobalKey<FormState>();
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
  final _regOtpController = TextEditingController();


  final _forgotInputController = TextEditingController(); // Mobile or Email
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  void _showError(String message) => SnackbarHelper.showError(context, message);

  void _showSuccess(String message) => SnackbarHelper.showSuccess(context, message);

  // --- API CALLS ---

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/login'),
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

        if (roles.any((r) => ['customer', 'turf-admin', 'manager', 'saas-admin'].contains(r))) {
          widget.onLoginSuccess(token, user);
          _showSuccess('Welcome back, ${user['name']}!');
        } else {
          _showError('Access denied. You do not have permission to log in.');
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

  // Step 1 Registration: Enter Mobile & Send WhatsApp OTP
  Future<void> _handleStep1SendMobileOtp() async {
    if (!_regMobileFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/send-whatsapp-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile': _regMobileController.text.trim(),
          'purpose': 'registration',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _regOtpController.clear();
        _showSuccess('WhatsApp OTP sent to ${_regMobileController.text.trim()}.');
        setState(() => _state = AuthState.regOtp);
      } else {
        _showError(data['message'] ?? 'Failed to send WhatsApp OTP.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Step 2 Registration: Verify WhatsApp OTP
  Future<void> _handleStep2VerifyOtp() async {
    if (!_regOtpFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/verify-whatsapp-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile': _regMobileController.text.trim(),
          'otp': _regOtpController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('Mobile verified successfully!');
        setState(() => _state = AuthState.regProfile);
      } else {
        _showError(data['message'] ?? 'Invalid or expired OTP.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Step 3 Registration: Save Name & Email -> Proceed to Password
  void _handleStep3Profile() {
    if (!_regProfileFormKey.currentState!.validate()) return;
    setState(() => _state = AuthState.regPassword);
  }

  // Step 4 Registration: Complete Registration
  Future<void> _handleStep4CompleteRegistration() async {
    if (!_regPasswordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/register'),
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
      final input = _forgotInputController.text.trim();
      final isEmail = input.contains('@');

      final response = await http.post(
        Uri.parse(isEmail ? '${ApiClient.baseUrl}/forgot-password' : '${ApiClient.baseUrl}/send-whatsapp-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(isEmail ? {
          'email': input,
        } : {
          'mobile': input,
          'purpose': 'forgot_password',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _otpController.clear();
        _showSuccess(isEmail ? 'OTP sent to your email.' : 'OTP sent to your WhatsApp.');
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
      final input = _forgotInputController.text.trim();
      final isEmail = input.contains('@');

      final response = await http.post(
        Uri.parse(isEmail ? '${ApiClient.baseUrl}/verify-otp' : '${ApiClient.baseUrl}/verify-whatsapp-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (isEmail) 'email': input else 'mobile': input,
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
      final input = _forgotInputController.text.trim();
      final isEmail = input.contains('@');

      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': input,
          if (isEmail) 'email': input else 'mobile': input,
          'otp': _otpController.text.trim(),
          'password': _newPasswordController.text,
          'password_confirmation': _confirmNewPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('Password reset successfully. Please log in.');
        _loginInputController.text = input;
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
                if (_state == AuthState.regMobile) _buildRegMobileForm(theme, isDark),
                if (_state == AuthState.regOtp) _buildRegOtpForm(theme, isDark),
                if (_state == AuthState.regProfile) _buildRegProfileForm(theme, isDark),
                if (_state == AuthState.regPassword) _buildRegPasswordForm(theme, isDark),
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
                onTap: () => setState(() => _state = AuthState.regMobile),
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


  Widget _buildStepIndicator(int currentStep, String title, ThemeData theme, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of 4: $title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              '${currentStep * 25}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: currentStep / 4.0,
            minHeight: 8,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // STEP 1: MOBILE NUMBER INPUT
  Widget _buildRegMobileForm(ThemeData theme, bool isDark) {
    return Form(
      key: _regMobileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(1, 'Mobile Verification', theme, isDark),
          const Text(
            'Enter Mobile Number',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'We will send a 6-digit verification code via WhatsApp',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _regMobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'e.g. 9664588677',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().length < 10 ? 'Please enter a valid 10-digit mobile number' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleStep1SendMobileOtp,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Send WhatsApp OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
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

  // STEP 2: VERIFY OTP FORM
  Widget _buildRegOtpForm(ThemeData theme, bool isDark) {
    return Form(
      key: _regOtpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(2, 'Enter OTP', theme, isDark),
          const Text(
            'Verify WhatsApp OTP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter 6-digit code sent to ${_regMobileController.text}',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _regOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8.0),
            decoration: const InputDecoration(
              counterText: '',
              labelText: '6-Digit OTP',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().length != 6 ? 'Enter 6-digit OTP' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleStep2VerifyOtp,
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
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _handleStep1SendMobileOtp,
            child: const Text('Resend WhatsApp OTP'),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _state = AuthState.regMobile),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Change Mobile Number'),
          ),
        ],
      ),
    );
  }

  // STEP 3: PROFILE INFO FORM (Name & Email)
  Widget _buildRegProfileForm(ThemeData theme, bool isDark) {
    return Form(
      key: _regProfileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(3, 'Personal Info', theme, isDark),
          const Text(
            'Personal Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us your name and email address',
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
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your full name' : null,
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
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your email' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleStep3Profile,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Next: Set Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _state = AuthState.regOtp),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to OTP'),
          ),
        ],
      ),
    );
  }

  // STEP 4: SET PASSWORD FORM
  Widget _buildRegPasswordForm(ThemeData theme, bool isDark) {
    return Form(
      key: _regPasswordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(4, 'Set Password', theme, isDark),
          const Text(
            'Create Password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Set a secure password for your account',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _regPasswordController,
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
            validator: (value) => value == null || value.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: _obscurePassword,
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
            onPressed: _isLoading ? null : _handleStep4CompleteRegistration,
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
                : const Text('Complete Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _state = AuthState.regProfile),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Personal Info'),
          ),
        ],
      ),
    );
  }


  // FORGOT REQUEST FORM (Enter Email or Mobile)
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
            'Enter your registered Email or Mobile number to receive OTP',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _forgotInputController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email or Mobile Number',
              prefixIcon: Icon(Icons.contact_mail_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email or mobile' : null,
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
            'Enter the 6-digit verification code sent to ${_forgotInputController.text}',
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
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _state = AuthState.login),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }

}
