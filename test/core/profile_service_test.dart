import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:turf_booking/core/api_client.dart';
import 'package:turf_booking/core/profile_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiClient.client = mockClient;
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  group('ProfileService.updateProfile', () {
    test('returns success ProfileResult when API responds 200', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/profile'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Profile details updated successfully.',
            'user': {
              'id': 1,
              'name': 'Sandeep Rathod',
              'email': 'sandeep198558@gmail.com',
              'mobile': '9664588677',
            },
          }),
          200,
        ),
      );

      final result = await ProfileService.updateProfile(
        'test-token',
        name: 'Sandeep Rathod',
        email: 'sandeep198558@gmail.com',
        mobile: '9664588677',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Profile details updated successfully.');
    });

    test('returns failure ProfileResult when API responds with 422', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/profile'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'The email has already been taken.',
          }),
          422,
        ),
      );

      final result = await ProfileService.updateProfile(
        'test-token',
        name: 'Sandeep Rathod',
        email: 'sandeep198558@gmail.com',
        mobile: '9664588677',
      );

      expect(result.success, isFalse);
      expect(result.message, 'The email has already been taken.');
    });

    test('returns network error ProfileResult when exception is thrown', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/profile'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('Connection refused'));

      final result = await ProfileService.updateProfile(
        'test-token',
        name: 'Sandeep Rathod',
        email: 'sandeep198558@gmail.com',
        mobile: '9664588677',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Network error. Please try again.');
    });
  });

  group('ProfileService.changePassword', () {
    test('returns success ProfileResult when API responds 200', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/password'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Password updated successfully.',
          }),
          200,
        ),
      );

      final result = await ProfileService.changePassword(
        'test-token',
        currentPassword: 'password',
        newPassword: 'newpassword123',
        confirmPassword: 'newpassword123',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Password updated successfully.');
    });

    test('returns failure ProfileResult when current password is incorrect (422)', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/password'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Current password does not match our records.',
          }),
          422,
        ),
      );

      final result = await ProfileService.changePassword(
        'test-token',
        currentPassword: 'wrongpassword',
        newPassword: 'newpassword123',
        confirmPassword: 'newpassword123',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Current password does not match our records.');
    });

    test('returns network error ProfileResult when exception is thrown', () async {
      when(
        () => mockClient.put(
          Uri.parse('${ApiClient.baseUrl}/user/password'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('Network timeout'));

      final result = await ProfileService.changePassword(
        'test-token',
        currentPassword: 'password',
        newPassword: 'newpassword123',
        confirmPassword: 'newpassword123',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Network error. Please try again.');
    });
  });

  group('ProfileService.deleteAccount', () {
    test('returns success ProfileResult when API responds 200', () async {
      when(
        () => mockClient.delete(
          Uri.parse('${ApiClient.baseUrl}/user'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': 'Your account has been deleted successfully.',
          }),
          200,
        ),
      );

      final result = await ProfileService.deleteAccount('test-token');

      expect(result.success, isTrue);
      expect(result.message, 'Your account has been deleted successfully.');
    });

    test('returns failure ProfileResult when API responds with error status', () async {
      when(
        () => mockClient.delete(
          Uri.parse('${ApiClient.baseUrl}/user'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Cannot delete account with active bookings.',
          }),
          400,
        ),
      );

      final result = await ProfileService.deleteAccount('test-token');

      expect(result.success, isFalse);
      expect(result.message, 'Cannot delete account with active bookings.');
    });

    test('returns network error ProfileResult when exception is thrown', () async {
      when(
        () => mockClient.delete(
          Uri.parse('${ApiClient.baseUrl}/user'),
          headers: any(named: 'headers'),
        ),
      ).thenThrow(Exception('Socket closed'));

      final result = await ProfileService.deleteAccount('test-token');

      expect(result.success, isFalse);
      expect(result.message, 'Network error. Please try again.');
    });
  });
}
