import 'dart:convert';
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'auth_storage.dart';

class ApiClient {
  static const String baseUrl = 'https://barberbackend-production-7a8a.up.railway.app/api/v1';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const _timeout = Duration(seconds: 15);

  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['data'];
    }
    // Include field-level validation errors in the message.
    final errors = body['errors'] as List?;
    String message = (body['message'] as String?) ?? 'Request failed';
    if (errors != null && errors.isNotEmpty) {
      final details = errors
          .map((e) => '${e['field']}: ${e['message']}')
          .join(', ');
      message = '$message ($details)';
    }
    throw ApiException(message, res.statusCode);
  }

  // Public parse helper for multipart responses
  static dynamic parseResponse(http.Response res) => _parse(res);

  /// Upload a single image file (no auth required).
  /// Returns the public URL string, or null on failure.
  static Future<String?> uploadFile(File file) async {
    try {
      final uri     = Uri.parse('$baseUrl/barbers/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file', file.path,
          filename: p.basename(file.path),
        ));
      final streamed = await request.send().timeout(_timeout);
      final body     = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return (body['data'] as Map<String, dynamic>?)?['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
