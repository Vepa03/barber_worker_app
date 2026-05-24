import 'dart:io';
import 'api_client.dart';
import 'auth_storage.dart';

class BarberAuthService {
  /// Register barber with full onboarding data.
  static Future<void> register({
    required String phone,
    required String firstName,
    required String lastName,
    required String salonName,
    String venueType = 'barber',
    String? cityId,
    String? cityName,
    String? tagline,
    String? about,
    int? yearsOfExperience,
    List<Map<String, String>>? services,
    List<Map<String, dynamic>>? workingHours,
    String? coverPhotoUrl,
    String? profilePhotoUrl,
    List<String>? portfolioUrls,
  }) async {
    await AuthStorage.saveRegistrationData(
      phone:              phone,
      firstName:          firstName,
      lastName:           lastName,
      salonName:          salonName,
      venueType:          venueType,
      cityId:             cityId,
      cityName:           cityName,
      tagline:            tagline,
      about:              about,
      yearsOfExperience:  yearsOfExperience,
      services:           services?.map((s) => Map<String, dynamic>.from(s)).toList(),
      workingHours:       workingHours,
      coverPhotoUrl:      coverPhotoUrl,
      profilePhotoUrl:    profilePhotoUrl,
      portfolioUrls:      portfolioUrls,
    );

    final body = <String, dynamic>{
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
      'salonName': salonName,
      'venueType': venueType,
      if (cityId != null) 'cityId': cityId,
      if (tagline != null && tagline.isNotEmpty) 'tagline': tagline,
      if (about != null && about.isNotEmpty) 'about': about,
      if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
      if (services != null && services.isNotEmpty) 'services': services,
      if (workingHours != null && workingHours.isNotEmpty) 'workingHours': workingHours,
      if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (portfolioUrls != null && portfolioUrls.isNotEmpty) 'portfolioUrls': portfolioUrls,
    };

    await ApiClient.post('/barbers/register', body);
  }

  /// Check approval status.
  /// Falls back to local status when the endpoint is unavailable.
  static Future<String> checkStatus(String phone) async {
    try {
      final data = await ApiClient.post(
        '/barbers/check-status',
        {'phone': phone},
      ) as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'pending';
      await AuthStorage.saveStatus(status);
      return status;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return (await AuthStorage.getStatus()) ?? 'pending';
      }
      rethrow;
    } on SocketException {
      return (await AuthStorage.getStatus()) ?? 'pending';
    }
  }

  /// Request OTP for approved barbers.
  static Future<void> requestOtp(String phone) async {
    await ApiClient.post('/barbers/auth/request-otp', {'phone': phone});
  }

  /// Verify OTP and save tokens.
  static Future<void> verifyOtp(String phone, String code) async {
    final data = await ApiClient.post('/barbers/auth/verify-otp', {
      'phone': phone,
      'code': code,
    }) as Map<String, dynamic>;

    await AuthStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      barberId:
          (data['barber'] as Map<String, dynamic>?)?['id'] as String?,
    );
  }

  static Future<void> logout() async {
    await AuthStorage.clearTokens();
  }
}
