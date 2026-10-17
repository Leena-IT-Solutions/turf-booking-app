import 'dart:convert';
import 'api_client.dart';

class ProfileResult {
  final bool success;
  final String message;

  const ProfileResult({required this.success, required this.message});
}

class ProfileService {
  ProfileService._();

  static Future<ProfileResult> updateProfile(
    String token, {
    required String name,
    required String email,
    required String mobile,
  }) async {
    try {
      final response = await ApiClient.put(
        Uri.parse('${ApiClient.baseUrl}/user/profile'),
        headers: ApiClient.authHeaders(token),
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'mobile': mobile.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ProfileResult(
          success: true,
          message: data['message'] ?? 'Profile details updated successfully.',
        );
      } else {
        return ProfileResult(
          success: false,
          message: data['message'] ?? 'Failed to update profile.',
        );
      }
    } catch (e) {
      return const ProfileResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  static Future<ProfileResult> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await ApiClient.put(
        Uri.parse('${ApiClient.baseUrl}/user/password'),
        headers: ApiClient.authHeaders(token),
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ProfileResult(
          success: true,
          message: data['message'] ?? 'Password updated successfully.',
        );
      } else {
        return ProfileResult(
          success: false,
          message: data['message'] ?? 'Failed to change password.',
        );
      }
    } catch (e) {
      return const ProfileResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  static Future<ProfileResult> deleteAccount(String token) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiClient.baseUrl}/user'),
        headers: ApiClient.authHeaders(token),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ProfileResult(
          success: true,
          message: data['message'] ?? 'Your account has been deleted successfully.',
        );
      } else {
        return ProfileResult(
          success: false,
          message: data['message'] ?? 'Failed to delete account.',
        );
      }
    } catch (e) {
      return const ProfileResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }
}
