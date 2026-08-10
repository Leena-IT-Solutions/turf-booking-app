/// Shared API configuration: single source of truth for the backend base URL
/// and authenticated request headers. Replaces the 6 duplicated `_baseUrl`
/// declarations and 16 duplicated inline `Authorization: Bearer` header maps
/// that previously existed across screens in main.dart.
class ApiClient {
  ApiClient._();

  static const String baseUrl = 'https://turf.infoleena.com/api';

  /// Standard JSON + bearer-token headers used by every authenticated
  /// request. Pass `null`/empty token to get headers without Authorization
  /// (matches prior behavior where some calls ran before a token existed).
  static Map<String, String> authHeaders(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
