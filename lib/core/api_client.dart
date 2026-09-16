import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Shared API configuration: single source of truth for the backend base URL,
/// authenticated request headers, automatic 401 Unauthorized handling, and
/// global navigation state.
class ApiClient {
  ApiClient._();

  static const String baseUrl = 'https://turf.infoleena.com/api';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Callback invoked whenever an API response returns 401 Unauthorized.
  /// Used by the root app to automatically clear local storage and route to AuthScreen.
  static VoidCallback? onUnauthorized;

  /// Standard JSON + bearer-token headers used by every authenticated
  /// request. Pass `null`/empty token to get headers without Authorization.
  static Map<String, String> authHeaders(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Inspects response status. If 401 Unauthorized, triggers [onUnauthorized].
  static http.Response checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }

  /// Convenience GET with automatic 401 check
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    return checkResponse(response);
  }

  /// Convenience POST with automatic 401 check
  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.post(url, headers: headers, body: body, encoding: encoding);
    return checkResponse(response);
  }

  /// Convenience PUT with automatic 401 check
  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.put(url, headers: headers, body: body, encoding: encoding);
    return checkResponse(response);
  }

  /// Convenience DELETE with automatic 401 check
  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
    return checkResponse(response);
  }
}

