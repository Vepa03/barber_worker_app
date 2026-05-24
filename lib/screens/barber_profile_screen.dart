import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/barber_auth_service.dart';
import '../services/barber_profile_service.dart';
import '../utils/theme_service.dart';
import 'barber_login_screen.dart';
import 'barber_profile_edit_screen.dart';

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});
  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  // ── Fixed palette ─────────────────────────────────────────────────────────────
  static const _blue  = Color(0xFF3875F6);
  static const _grey  = Color(0xFF8E8E93);
  static const _avatarColors = [
    Color(0xFF3875F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFF22C55E),
  ];

  // ── Theme-aware helpers ───────────────────────────────────────────────────────
  Color _bg(BuildContext ctx) =>
      Theme.of(ctx).scaffoldBackgroundColor;
  Color _surface(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surface;
  Color _textPrimary(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface;
  Color _border(BuildContext ctx) =>
      Theme.of(ctx).dividerColor;

  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await BarberProfileService.getProfile();
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        await AuthStorage.clearTokens();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()));
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Computed ──────────────────────────────────────────────────────────────────
  Color _avatarColor(String s) {
    int h = 0;
    for (final c in s.runes) { h = (h * 31 + c) & 0xFFFFFFFF; }
    return _avatarColors[h % _avatarColors.length];
  }

  String _initials(String s) {
    final p = s.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  bool get _complete => _profile?['profileComplete'] == true;

  String get _fullName {
    if (_profile == null) return '';
    if (_complete) {
      final nm = _profile!['name'] as String? ?? '';
      return nm;
    }
    final f = (_profile!['firstName'] as String?) ?? '';
    final l = (_profile!['lastName']  as String?) ?? '';
    return '$f $l'.trim();
  }

  String get _salonName {
    if (_complete) return (_profile!['name'] as String?) ?? '';
    return (_profile?['salonName'] as String?) ?? '';
  }

  String get _avatarUrl => (_profile?['avatarImage'] as String?) ?? '';

  String get _venueLabel {
    final v = (_profile?['venueType'] as String?) ?? '';
    return switch (v) {
      'barber'       => 'Barber',
      'womens_salon' => 'Salon',
      'massage'      => 'Massage',
      'car_wash'     => 'Car wash',
      _              => v,
    };
  }

  String get _cityName =>
      (_profile?['city'] as Map?)?['name'] as String? ?? '';

  int get _serviceCount =>
      (_profile?['services'] as List?)?.length ?? 0;

  String get _workingDaysLabel {
    final hours = (_profile?['workingHours'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (hours.isEmpty) return '—';
    const short = {
      'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
      'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun',
    };
    final open = hours
        .where((h) => !(h['isClosed'] as bool? ?? false))
        .map((h) => short[h['day']] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (open.isEmpty) return 'Closed';
    if (open.length == 7) return 'Every day';
    return '${open.first} – ${open.last}';
  }

  String get _locationLabel {
    final city    = _cityName;
    final address = (_profile?['address'] as String?) ?? '';
    if (city.isNotEmpty && address.isNotEmpty) {
      final parts = address.split(',');
      return parts.length > 1 ? '$city, ${parts.last.trim()}' : city;
    }
    return city.isNotEmpty ? city : address;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (ctx, mode, _) => Scaffold(
        backgroundColor: _bg(ctx),
        body: SafeArea(
          child: Column(children: [
            _buildTopBar(ctx),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: _blue, strokeWidth: 2.5))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _blue,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildProfileCard(ctx),
                          const SizedBox(height: 28),
                          _buildSection(ctx, 'BUSINESS', [
                            _item(ctx,
                              icon: Icons.storefront_outlined,
                              label: 'Shop details',
                              value: _salonName.isNotEmpty ? _salonName : '—',
                              onTap: () => _openEditTab(0),
                            ),
                            _item(ctx,
                              icon: Icons.content_cut_rounded,
                              label: 'Services & prices',
                              value: _serviceCount > 0
                                  ? '$_serviceCount service${_serviceCount != 1 ? 's' : ''}'
                                  : '—',
                              onTap: () => _openEditTab(1),
                            ),
                            _item(ctx,
                              icon: Icons.calendar_today_outlined,
                              label: 'Working hours',
                              value: _complete ? _workingDaysLabel : '—',
                              onTap: () => _openEditTab(2),
                            ),
                            _item(ctx,
                              icon: Icons.location_on_outlined,
                              label: 'Location',
                              value: _locationLabel.isNotEmpty ? _locationLabel : '—',
                              onTap: () => _openEditTab(0),
                              isLast: true,
                            ),
                          ]),
                          const SizedBox(height: 28),
                          _buildSection(ctx, 'APP', [
                            _item(ctx,
                              icon: mode == ThemeMode.dark
                                  ? Icons.dark_mode_outlined
                                  : Icons.wb_sunny_outlined,
                              label: 'Appearance',
                              value: themeLabel(mode),
                              onTap: () => _showThemePicker(ctx),
                            ),
                            _item(ctx,
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              onTap: () {},
                            ),
                            _item(ctx,
                              icon: Icons.shield_outlined,
                              label: 'Privacy & security',
                              onTap: () {},
                              isLast: true,
                            ),
                          ]),
                          const SizedBox(height: 28),
                          _buildSection(ctx, 'ACCOUNT', [
                            _item(ctx,
                              icon: Icons.logout_rounded,
                              label: 'Log out',
                              labelColor: Colors.redAccent,
                              iconColor: Colors.redAccent,
                              onTap: _confirmLogout,
                              showChevron: false,
                              isLast: true,
                            ),
                          ]),
                        ],
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Row(children: [
      Expanded(
        child: Text('Profile', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800,
            color: _textPrimary(ctx), letterSpacing: -0.5)),
      ),
      GestureDetector(
        onTap: _openEdit,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _surface(ctx),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border(ctx)),
          ),
          child: Icon(Icons.settings_outlined, size: 20,
              color: _textPrimary(ctx)),
        ),
      ),
    ]),
  );

  // ── Profile card ──────────────────────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext ctx) {
    final name = _fullName.isNotEmpty ? _fullName : 'Berber';
    final col  = _avatarColor(name);
    final ini  = _initials(name);

    return GestureDetector(
      onTap: _openEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface(ctx),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: col.withValues(alpha: 0.15),
              image: _avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: _avatarUrl.isEmpty
                ? Center(child: Text(ini, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: col)))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: _textPrimary(ctx))),
              if (_salonName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(_salonName,
                    style: const TextStyle(fontSize: 13, color: _grey)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (_venueLabel.isNotEmpty)
                  _tag(ctx, Icons.content_cut_rounded, _venueLabel),
                if (_cityName.isNotEmpty)
                  _tag(ctx, Icons.location_on_outlined, _cityName),
              ]),
            ]),
          ),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _bg(ctx), shape: BoxShape.circle),
            child: const Icon(Icons.chevron_right_rounded,
                size: 18, color: _grey),
          ),
        ]),
      ),
    );
  }

  Widget _tag(BuildContext ctx, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _bg(ctx),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border(ctx)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _grey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: _grey)),
    ]),
  );

  // ── Section ───────────────────────────────────────────────────────────────────
  Widget _buildSection(BuildContext ctx, String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _grey, letterSpacing: 0.6)),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surface(ctx),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Column(children: items),
        ),
      ]);

  Widget _item(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    String? value,
    required VoidCallback onTap,
    Color? labelColor,
    Color? iconColor,
    bool showChevron = true,
    bool isLast = false,
  }) {
    return Column(children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(children: [
            Icon(icon, size: 20,
                color: iconColor ?? const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500,
                  color: labelColor ?? _textPrimary(ctx))),
            ),
            if (value != null) ...[
              Text(value, style: const TextStyle(
                  fontSize: 14, color: _grey)),
              const SizedBox(width: 4),
            ],
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _grey),
          ]),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 52, color: _border(ctx)),
    ]);
  }

  // ── Theme picker ─────────────────────────────────────────────────────────────
  void _showThemePicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface(ctx),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _border(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Appearance', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: _textPrimary(ctx))),
            const SizedBox(height: 16),
            ...{
              ThemeMode.light:  ('Light',  Icons.wb_sunny_rounded),
              ThemeMode.dark:   ('Dark',   Icons.dark_mode_rounded),
              ThemeMode.system: ('System', Icons.brightness_auto_rounded),
            }.entries.map((e) {
              final selected = themeNotifier.value == e.key;
              return GestureDetector(
                onTap: () {
                  setTheme(e.key);
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? _blue.withValues(alpha: 0.10)
                        : _bg(ctx),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _blue : _border(ctx),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(e.value.$2,
                        size: 20,
                        color: selected ? _blue : const Color(0xFF6B7280)),
                    const SizedBox(width: 14),
                    Text(e.value.$1, style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: selected ? _blue : _textPrimary(ctx))),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_rounded,
                          size: 18, color: _blue),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────────
  Future<void> _openEdit() => _openEditTab(0);

  Future<void> _openEditTab(int tab) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BarberProfileEditScreen(
          existingProfile: _profile,
          initialTab: tab,
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await BarberAuthService.logout();
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()));
      }
    }
  }
}
