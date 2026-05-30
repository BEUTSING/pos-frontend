// ─────────────────────────────────────────────────────────────────────────────
// FILE: api_service.dart
// PURPOSE: Centralized HTTP service — all API calls go through this file
//
// IMPORTANT — GET with body:
//   Some Symfony routes use GET method but expect a JSON body
//   (e.g. /sale_history/period, /sale_history/teller).
//   Standard HTTP clients don't support GET + body well on web.
//   SOLUTION: we use query parameters (?period=today) for GET requests
//   that need to pass data. Use getWithParams() for these cases.
//
// TOKEN EXPIRY:
//   When Symfony returns 401, the JWT token has expired.
//   We clear the token and redirect to login automatically.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// Callback called when token expires — set by main.dart
// This avoids circular imports between api_service and login_page
typedef OnTokenExpired = void Function();

class ApiService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Token expiry callback — set once in main.dart ─────────────────────────
  // When a 401 is received, this function is called to navigate to login
  OnTokenExpired? onTokenExpired;

  // ── _getToken ─────────────────────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kTokenKey);
  }

  // ── _headers ──────────────────────────────────────────────────────────────
  // Builds HTTP headers for every request.
  // X-Company-Id tells Symfony which company to use for filtering data.
  // This is needed when an admin has multiple companies — Symfony reads
  // this header in CompanyService.getCurrentCompany() to return the right one.
  Future<Map<String, String>> _headers() async {
    final token     = await _getToken();
    final companyId = await _getCompanyId();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // JWT token — required for all protected routes
      if (token != null) 'Authorization': 'Bearer $token',
      // Active company ID — tells Symfony which restaurant to filter by
      if (companyId.isNotEmpty) 'X-Company-Id': companyId,
    };
  }

  // ── _getCompanyId — reads active company from local storage ───────────────
  Future<String> _getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('companyId') ?? '';
  }

  // ── GET — simple GET without body ─────────────────────────────────────────
  Future<ApiResponse> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl$endpoint'),
        headers: await _headers(),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── GET WITH BODY — sends a GET request with a JSON body ─────────────────
  // Used for Symfony routes that are declared as GET but read json body
  // Standard http.get() doesn't support body, so we use http.Request
  Future<ApiResponse> getWithBody(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final request = http.Request('GET', Uri.parse('$kBaseUrl$endpoint'));
      final headers = await _headers();
      request.headers.addAll(headers);
      request.body = jsonEncode(body);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── GET WITH PARAMS — GET with query string parameters ────────────────────
  // Used for Symfony routes that are GET but need parameters
  // Example: /sale_history/period?period=today
  // Example: /sale_history/teller?teller_id=3
  Future<ApiResponse> getWithParams(
      String endpoint, Map<String, dynamic> params) async {
    try {
      // Convert params map to query string
      // {'period': 'today'} → '?period=today'
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final url = '$kBaseUrl$endpoint?$queryString';

      final response = await http.get(
        Uri.parse(url),
        headers: await _headers(),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── POST — send JSON body ──────────────────────────────────────────────────
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl$endpoint'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── PUT — update existing data ────────────────────────────────────────────
  Future<ApiResponse> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('$kBaseUrl$endpoint'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<ApiResponse> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBaseUrl$endpoint'),
        headers: await _headers(),
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'Erreur réseau: $e');
    }
  }

  // ── _handleResponse ───────────────────────────────────────────────────────
  ApiResponse _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic body;

    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    // ── 401 Unauthorized ─────────────────────────────────────────────────
    // Two cases:
    //   1. "Expired JWT Token"  → token expired → clear + redirect to login
    //   2. "Invalid credentials" / "email and password" → wrong password
    //      → return error normally, do NOT redirect (user is on login page)
    if (statusCode == 401) {
      // Extract the error message from the response body
      String msg401 = '';
      if (body is Map) {
        msg401 = (body['message'] ?? body['error'] ?? '').toString().toLowerCase();
      } else if (body is String) {
        msg401 = body.toLowerCase();
      }

      // Only redirect if it's a JWT token expiry — NOT a wrong password
      final isTokenExpired = msg401.contains('expired jwt') ||
          msg401.contains('jwt token not found') ||
          msg401.contains('invalid jwt') ||
          msg401.contains('unable to find token');

      if (isTokenExpired) {
        // Token expired → clear storage and go to login
        _clearTokenAndRedirect();
        return ApiResponse(
          success: false,
          error: 'Session expirée. Veuillez vous reconnecter.',
          statusCode: 401,
        );
      } else {
        // Wrong credentials → return the error message normally
        // Do NOT redirect — login_page will show the error in a snackbar
        final errorMsg = body is Map
            ? (body['error'] ?? body['message'] ?? 'Identifiants invalides')
            : 'Identifiants invalides';
        return ApiResponse(
          success: false,
          error: errorMsg.toString(),
          statusCode: 401,
        );
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return ApiResponse(success: true, data: body, statusCode: statusCode);
    } else {
      String errorMsg = 'Erreur $statusCode';
      if (body is Map) {
        errorMsg = body['error'] ?? body['message'] ?? errorMsg;
      }
      return ApiResponse(
          success: false, error: errorMsg, statusCode: statusCode);
    }
  }

  // ── _clearTokenAndRedirect ────────────────────────────────────────────────
  // Called when a 401 is received — clears JWT and calls the expiry callback
  Future<void> _clearTokenAndRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey); // remove expired token
    await prefs.remove(kUserName);
    await prefs.remove(kUserRole);
    await prefs.remove(kCompanyName);
    await prefs.remove(kCompanyId);
    // Trigger navigation to login (callback set in main.dart)
    onTokenExpired?.call();
  }
}

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });
}