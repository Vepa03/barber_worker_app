import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  // ── Auth ───────────────────────────────────────────────────────────────────
  static const _tokenKey    = 'barber_access_token';
  static const _refreshKey  = 'barber_refresh_token';
  static const _barberIdKey = 'barber_id';
  static const _statusKey   = 'barber_status';

  // ── Basic registration ─────────────────────────────────────────────────────
  static const _phoneKey      = 'barber_phone';
  static const _firstNameKey  = 'barber_first_name';
  static const _lastNameKey   = 'barber_last_name';
  static const _salonNameKey  = 'barber_salon_name';
  static const _venueTypeKey  = 'barber_venue_type';

  // ── Extended onboarding ────────────────────────────────────────────────────
  static const _cityIdKey         = 'barber_city_id';
  static const _cityNameKey       = 'barber_city_name';
  static const _taglineKey        = 'barber_tagline';
  static const _aboutKey          = 'barber_about';
  static const _yearsKey          = 'barber_years_exp';
  static const _servicesKey       = 'barber_services';
  static const _workingHoursKey   = 'barber_working_hours';
  static const _coverPhotoKey     = 'barber_cover_photo_url';
  static const _profilePhotoKey   = 'barber_profile_photo_url';
  static const _portfolioKey      = 'barber_portfolio_urls';

  // ── Status ─────────────────────────────────────────────────────────────────
  static Future<String?> getStatus() async =>
      (await SharedPreferences.getInstance()).getString(_statusKey);

  static Future<void> saveStatus(String status) async =>
      (await SharedPreferences.getInstance()).setString(_statusKey, status);

  // ── Phone ──────────────────────────────────────────────────────────────────
  static Future<void> savePhone(String phone) async =>
      (await SharedPreferences.getInstance()).setString(_phoneKey, phone);

  static Future<String?> getPhone() async =>
      (await SharedPreferences.getInstance()).getString(_phoneKey);

  // ── Full registration data ─────────────────────────────────────────────────
  static Future<void> saveRegistrationData({
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
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? workingHours,
    String? coverPhotoUrl,
    String? profilePhotoUrl,
    List<String>? portfolioUrls,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey,     phone);
    await prefs.setString(_firstNameKey, firstName);
    await prefs.setString(_lastNameKey,  lastName);
    await prefs.setString(_salonNameKey, salonName);
    await prefs.setString(_venueTypeKey, venueType);
    await prefs.setString(_statusKey,    'pending');

    if (cityId   != null) await prefs.setString(_cityIdKey,   cityId);
    if (cityName != null) await prefs.setString(_cityNameKey, cityName);
    if (tagline  != null) await prefs.setString(_taglineKey,  tagline);
    if (about    != null) await prefs.setString(_aboutKey,    about);
    if (yearsOfExperience != null) await prefs.setInt(_yearsKey, yearsOfExperience);
    if (services     != null) await prefs.setString(_servicesKey,     jsonEncode(services));
    if (workingHours != null) await prefs.setString(_workingHoursKey, jsonEncode(workingHours));
    if (coverPhotoUrl   != null) await prefs.setString(_coverPhotoKey,   coverPhotoUrl);
    if (profilePhotoUrl != null) await prefs.setString(_profilePhotoKey, profilePhotoUrl);
    if (portfolioUrls   != null) await prefs.setString(_portfolioKey,    jsonEncode(portfolioUrls));
  }

  static Future<Map<String, dynamic>> getFullRegistrationData() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic>? services, workingHours, portfolio;
    final svcStr  = prefs.getString(_servicesKey);
    final whStr   = prefs.getString(_workingHoursKey);
    final portStr = prefs.getString(_portfolioKey);
    if (svcStr  != null) services     = jsonDecode(svcStr)  as List;
    if (whStr   != null) workingHours = jsonDecode(whStr)   as List;
    if (portStr != null) portfolio    = jsonDecode(portStr) as List;
    return {
      'phone':             prefs.getString(_phoneKey),
      'firstName':         prefs.getString(_firstNameKey),
      'lastName':          prefs.getString(_lastNameKey),
      'salonName':         prefs.getString(_salonNameKey),
      'venueType':         prefs.getString(_venueTypeKey),
      'cityId':            prefs.getString(_cityIdKey),
      'cityName':          prefs.getString(_cityNameKey),
      'tagline':           prefs.getString(_taglineKey),
      'about':             prefs.getString(_aboutKey),
      'yearsOfExperience': prefs.getInt(_yearsKey),
      'services':          services,
      'workingHours':      workingHours,
      'coverPhotoUrl':     prefs.getString(_coverPhotoKey),
      'profilePhotoUrl':   prefs.getString(_profilePhotoKey),
      'portfolioUrls':     portfolio,
    };
  }

  // ── Tokens ─────────────────────────────────────────────────────────────────
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? barberId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (refreshToken != null) await prefs.setString(_refreshKey,  refreshToken);
    if (barberId     != null) await prefs.setString(_barberIdKey, barberId);
    await prefs.setString(_statusKey, 'approved');
  }

  static Future<String?> getAccessToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<String?> getBarberId() async =>
      (await SharedPreferences.getInstance()).getString(_barberIdKey);

  static Future<bool> isLoggedIn() async => (await getAccessToken()) != null;

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _tokenKey, _refreshKey, _barberIdKey, _statusKey,
      _phoneKey, _firstNameKey, _lastNameKey, _salonNameKey, _venueTypeKey,
      _cityIdKey, _cityNameKey, _taglineKey, _aboutKey, _yearsKey,
      _servicesKey, _workingHoursKey, _coverPhotoKey, _profilePhotoKey, _portfolioKey,
    ]) { await prefs.remove(k); }
  }
}
