import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_storage.dart';
import '../services/barber_auth_service.dart';
import 'barber_login_screen.dart';
import 'barber_register_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;
  Timer? _pollTimer;
  bool _checking = false;
  Map<String, dynamic> _data = {};

  static const _bg     = Color(0xFFF4F4F4);
  static const _black  = Color(0xFF1A1A1A);
  static const _grey   = Color(0xFF888888);
  static const _greyL  = Color(0xFFAAAAAA);
  static const _border = Color(0xFFE8E8E8);
  static const _blue   = Color(0xFF3875F6);
  static const _blueBg = Color(0xFFEBF2FE);
  static const _amber  = Color(0xFFF59E0B);
  static const _amberBg = Color(0xFFFEF3C7);

  static const _venueLabels = {
    'barber':       'Berber',
    'womens_salon': 'Kadın Salonu',
    'massage':      'Masaj',
    'car_wash':     'Araç Yıkama',
  };
  static const _daysTr = {
    'Mon': 'Pzt', 'Tue': 'Sal', 'Wed': 'Çar',
    'Thu': 'Per', 'Fri': 'Cum', 'Sat': 'Cmt', 'Sun': 'Paz',
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkApproval());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final d = await AuthStorage.getFullRegistrationData();
    if (mounted) setState(() => _data = d);
  }

  Future<void> _checkApproval() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final phone = await AuthStorage.getPhone();
      if (phone == null) { _resetToRegister(); return; }
      final status = await BarberAuthService.checkStatus(phone);
      if (!mounted) return;
      if (status == 'approved') {
        _pollTimer?.cancel();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()));
      } else if (status == 'not_found') {
        await AuthStorage.clearAll();
        if (mounted) _resetToRegister();
      } else {
        setState(() => _checking = false);
        _snack('Henüz onay bekleniyor...');
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _black,
    ));
  }

  void _resetToRegister() {
    _pollTimer?.cancel();
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const BarberRegisterScreen()));
  }

  Future<void> _resetAndRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Yeniden Başvur', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Mevcut başvuru silinecek. Devam etmek istiyor musun?',
            style: TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Evet, Sıfırla',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await AuthStorage.clearAll();
      if (mounted) _resetToRegister();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _statusBanner(),
              const SizedBox(height: 24),
              _profileCard(),
              const SizedBox(height: 16),
              if (_hasServices) _servicesCard(),
              if (_hasServices) const SizedBox(height: 16),
              if (_hasSchedule) _scheduleCard(),
              if (_hasSchedule) const SizedBox(height: 16),
              if (_hasPortfolio) _portfolioCard(),
              if (_hasPortfolio) const SizedBox(height: 16),
              _actionsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────
  Widget _statusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('⏳', style: TextStyle(fontSize: 24))),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Onay Bekleniyor',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 4),
              const Text('Başvurun alındı. Admin inceledikten sonra hesabın aktif olacak.',
                  style: TextStyle(fontSize: 13, color: _grey, height: 1.4)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _profileCard() {
    final firstName  = _data['firstName'] as String? ?? '';
    final lastName   = _data['lastName']  as String? ?? '';
    final salonName  = _data['salonName'] as String? ?? '';
    final venueType  = _data['venueType'] as String? ?? 'barber';
    final cityName   = _data['cityName']  as String?;
    final tagline    = _data['tagline']   as String?;
    final about      = _data['about']     as String?;
    final years      = _data['yearsOfExperience'] as int?;
    final phone      = _data['phone'] as String?;
    final coverUrl   = _data['coverPhotoUrl']   as String?;
    final profileUrl = _data['profilePhotoUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover photo
        if (coverUrl != null)
          SizedBox(
            width: double.infinity, height: 140,
            child: _NetworkOrFile(url: coverUrl, fit: BoxFit.cover),
          )
        else
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue.withOpacity(0.7), _blue],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Profile photo
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                clipBehavior: Clip.antiAlias,
                child: profileUrl != null
                    ? _NetworkOrFile(url: profileUrl, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFE0E0E0),
                        child: Center(
                          child: Text(
                            (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : ''),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _grey),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$firstName $lastName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
                const SizedBox(height: 2),
                Text(salonName,
                    style: const TextStyle(fontSize: 14, color: _grey, fontWeight: FontWeight.w500)),
              ])),
            ]),

            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(Icons.content_cut_rounded, _venueLabels[venueType] ?? venueType, _blueBg, _blue),
              if (cityName != null) _chip(Icons.location_on_outlined, cityName, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
              if (phone != null) _chip(Icons.phone_outlined, phone, const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
              if (years != null) _chip(Icons.star_outline_rounded, '$years yıl deneyim', _amberBg, _amber),
            ]),

            if (tagline != null && tagline.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('"$tagline"',
                  style: const TextStyle(fontSize: 14, color: _grey, fontStyle: FontStyle.italic)),
            ],

            if (about != null && about.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionLabel('Hakkında'),
              const SizedBox(height: 6),
              Text(about, style: const TextStyle(fontSize: 14, color: _black, height: 1.6)),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Services card ─────────────────────────────────────────────────────────
  bool get _hasServices {
    final s = _data['services'] as List?;
    return s != null && s.isNotEmpty;
  }

  Widget _servicesCard() {
    final services = (_data['services'] as List).cast<Map>();
    return _card(
      icon: Icons.content_cut_rounded,
      title: 'Hizmetler',
      child: Column(
        children: services.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: i > 0 ? const Border(top: BorderSide(color: Color(0xFFF0F0F0))) : null,
            ),
            child: Row(children: [
              Expanded(
                child: Text(s['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black)),
              ),
              if (s['price'] != null && s['price'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('\$${s['price']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                ),
              if (s['duration'] != null && s['duration'].toString().isNotEmpty)
                Text('${s['duration']} dk',
                    style: const TextStyle(fontSize: 12, color: _greyL)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Schedule card ─────────────────────────────────────────────────────────
  bool get _hasSchedule {
    final s = _data['workingHours'] as List?;
    return s != null && s.isNotEmpty;
  }

  Widget _scheduleCard() {
    final hours = (_data['workingHours'] as List).cast<Map>();
    return _card(
      icon: Icons.calendar_today_outlined,
      title: 'Çalışma Saatleri',
      child: Column(
        children: hours.asMap().entries.map((e) {
          final i   = e.key;
          final wh  = e.value;
          final day = wh['day']?.toString() ?? '';
          final enabled = wh['enabled'] == true;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: i > 0 ? const Border(top: BorderSide(color: Color(0xFFF0F0F0))) : null,
            ),
            child: Row(children: [
              SizedBox(
                width: 40,
                child: Text(_daysTr[day] ?? day,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: enabled ? _black : _greyL,
                    )),
              ),
              if (enabled) ...[
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                ),
                Text('${wh['start']} – ${wh['end']}',
                    style: const TextStyle(fontSize: 14, color: _black)),
              ] else ...[
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: _greyL.withOpacity(0.4), shape: BoxShape.circle),
                ),
                const Text('Kapalı', style: TextStyle(fontSize: 14, color: _greyL)),
              ],
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Portfolio card ────────────────────────────────────────────────────────
  bool get _hasPortfolio {
    final p = _data['portfolioUrls'] as List?;
    return p != null && p.isNotEmpty;
  }

  Widget _portfolioCard() {
    final urls = (_data['portfolioUrls'] as List).cast<String>();
    return _card(
      icon: Icons.photo_library_outlined,
      title: 'Portfolyo (${urls.length} fotoğraf)',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: urls.length,
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _NetworkOrFile(url: urls[i], fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ── Actions card ──────────────────────────────────────────────────────────
  Widget _actionsCard() {
    return Column(children: [
      GestureDetector(
        onTap: _checking ? null : _checkApproval,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: _blue, borderRadius: BorderRadius.circular(32),
          ),
          child: Center(
            child: _checking
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Durumu Kontrol Et',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: _resetAndRestart,
          child: const Text('Yeniden başvur',
              style: TextStyle(fontSize: 13, color: _greyL,
                  decoration: TextDecoration.underline,
                  decorationColor: _greyL)),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _blueBg, borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('Onaylandığında seni haberdar edeceğiz.',
              style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w500)),
        ),
      ),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(title, icon: icon),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _sectionLabel(String title, {IconData? icon}) {
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: _greyL),
        const SizedBox(width: 6),
      ],
      Text(title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: _greyL, letterSpacing: 0.8,
          )),
    ]);
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

// ── Image widget (URL or local file) ─────────────────────────────────────────
class _NetworkOrFile extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _NetworkOrFile({required this.url, required this.fit});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return Image.network(url, fit: fit,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF0F0F0),
            child: const Icon(Icons.broken_image_outlined, color: Color(0xFFCCCCCC)),
          ));
    }
    final f = File(url);
    if (f.existsSync()) return Image.file(f, fit: fit);
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Icon(Icons.image_outlined, color: Color(0xFFCCCCCC)),
    );
  }
}
