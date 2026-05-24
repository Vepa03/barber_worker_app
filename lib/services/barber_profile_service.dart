import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'api_client.dart';
import 'auth_storage.dart';

class BarberProfileService {
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiClient.get('/barbers/me') as Map<String, dynamic>;
  }

  static Future<List<Map<String, String>>> getCities() async {
    final data = await ApiClient.get('/cities') as List;
    return data
        .map<Map<String, String>>((c) => {
              'id': c['id'] as String,
              'name': c['name'] as String,
            })
        .toList();
  }

  static Future<Map<String, dynamic>> saveProfile({
    required String name,
    required String cityId,
    required String address,
    required String about,
    required String coverImage,
    required String avatarImage,
    required List<Map<String, dynamic>> services,
    required List<String> portfolioUrls,
    required List<Map<String, dynamic>> workingHours,
  }) async {
    final result = await ApiClient.put('/barbers/me', {
      'name':          name,
      'cityId':        cityId,
      'address':       address,
      'about':         about,
      'coverImage':    coverImage.isNotEmpty ? coverImage : null,
      'avatarImage':   avatarImage.isNotEmpty ? avatarImage : null,
      'services':      services,
      'portfolioUrls': portfolioUrls,
      'workingHours':  workingHours,
    });
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// Upload using bytes (works reliably on macOS sandbox).
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await AuthStorage.getAccessToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/barbers/me/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final ext = p.extension(filename).toLowerCase();
    final mime = switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: http.MediaType.parse(mime),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = ApiClient.parseResponse(response);
    return body['url'] as String;
  }
}
