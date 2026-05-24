import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/barber_profile_service.dart';
import 'barber_appointments_screen.dart';
import 'barber_login_screen.dart';
import 'barber_schedule_screen.dart';
import 'barber_reviews_screen.dart';
import 'barber_profile_screen.dart';
import 'barber_notifications_screen.dart';
import '../utils/theme_ext.dart';

const _kGrey   = Color(0xFF888888);
const _kBlue   = Color(0xFF3875F6);
const _kDark   = Color(0xFF1A1A2E);

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});
  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  int _navIndex = 0;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await BarberProfileService.getProfile();
      List<Map<String, dynamic>> appts = [];
      try {
        final data = await ApiClient.get('/barbers/me/appointments') as List;
        appts = data.cast<Map<String, dynamic>>();
      } catch (_) {}
      if (mounted) setState(() { _profile = profile; _appointments = appts; });
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        await AuthStorage.clearTokens();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()));
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Veri yüklenemedi: ${e.message}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bağlantı hatası. Yenilemek için aşağı çekin.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Computed properties ───────────────────────────────────────────────────────
  String get _firstName {
    if (_profile == null) return '';
    if (_profile!['profileComplete'] == true) {
      final name = (_profile!['name'] as String?) ?? '';
      return name.split(' ').first;
    }
    return (_profile!['firstName'] as String?) ?? '';
  }

  String get _initials {
    final first = _firstName;
    if (first.isEmpty) return '?';
    final last = (_profile?['lastName'] as String?) ?? '';
    if (last.isNotEmpty) return '${first[0]}${last[0]}'.toUpperCase();
    return first[0].toUpperCase();
  }

  String get _avatarUrl => (_profile?['avatarImage'] as String?) ?? '';

  Map<String, dynamic>? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _appointments.where((a) {
      final at = DateTime.tryParse(a['scheduledAt'].toString());
      return at != null && at.isAfter(now) && a['status'] != 'cancelled';
    }).toList()
      ..sort((a, b) => DateTime.parse(a['scheduledAt'].toString())
          .compareTo(DateTime.parse(b['scheduledAt'].toString())));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<Map<String, dynamic>> get _restAppointments {
    final now = DateTime.now();
    final upcoming = _appointments.where((a) {
      final at = DateTime.tryParse(a['scheduledAt'].toString());
      return at != null && at.isAfter(now) && a['status'] != 'cancelled';
    }).toList()
      ..sort((a, b) => DateTime.parse(a['scheduledAt'].toString())
          .compareTo(DateTime.parse(b['scheduledAt'].toString())));
    return upcoming.length > 1 ? upcoming.sublist(1) : [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  static String _fmtDate(DateTime dt) {
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  static String _until(DateTime dt) {
    final mins = dt.difference(DateTime.now()).inMinutes;
    if (mins < 1)  return 'NOW';
    if (mins < 60) return 'IN $mins MIN';
    return 'IN ${mins ~/ 60}H ${mins % 60}MIN';
  }

  static String _customerInitials(String name) =>
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty)
          .take(2).map((p) => p[0].toUpperCase()).join();

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildNextUpCard(),
                    const SizedBox(height: 28),
                    _buildUpcomingSection(),
                  ]),
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BarberProfileScreen())),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBlue,
            image: _avatarUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover)
                : null,
          ),
          child: _avatarUrl.isEmpty
              ? Center(child: Text(_initials, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))
              : null,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtDate(DateTime.now()), style: const TextStyle(
              fontSize: 12, color: _kGrey, fontWeight: FontWeight.w500)),
          Text(
            'Hey ${_firstName.isNotEmpty ? _firstName : 'there'} 👋',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: context.kText, letterSpacing: -0.4),
          ),
        ]),
      ),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const BarberNotificationsScreen())),
        child: Stack(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: context.kBorder),
            ),
            child: Icon(Icons.notifications_outlined,
                size: 20, color: context.kText),
          ),
          // Badge: pending appointments count
          if (_appointments.any((a) => a['status'] == 'pending'))
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 12, height: 12,
                decoration: const BoxDecoration(
                  color: Colors.redAccent, shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 1.5)),
                ),
              ),
            ),
        ]),
      ),
    ]),
  );

  // ── Next Up Card ──────────────────────────────────────────────────────────────
  Widget _buildNextUpCard() {
    final next = _nextAppointment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: next == null ? _buildEmptyNextUp() : _buildFilledNextUp(next),
    );
  }

  Widget _buildEmptyNextUp() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 32),
    decoration: BoxDecoration(
      color: _kDark, borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(children: [
      Text('📅', style: TextStyle(fontSize: 36)),
      SizedBox(height: 12),
      Text('No upcoming appointments', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      SizedBox(height: 4),
      Text('Your schedule is clear', style: TextStyle(
          fontSize: 13, color: Colors.white54)),
    ]),
  );

  Widget _buildFilledNextUp(Map<String, dynamic> a) {
    final at      = DateTime.parse(a['scheduledAt'].toString()).toLocal();
    final cust    = a['customer'] as Map? ?? {};
    final name    = (cust['fullName'] as String?) ?? 'Customer';
    final phone   = (cust['phone']    as String?) ?? '';
    final svcs    = (a['services'] as List? ?? []).cast<Map<String, dynamic>>();
    final svcText = svcs.map((s) => s['name'] as String? ?? '').join(' + ');
    final dur     = (a['totalDurationMin'] as int?) ?? 0;
    final inits   = _customerInitials(name);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kDark, borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('NEXT UP · ${_until(at)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white70, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // customer avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(inits, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Text(svcText.isNotEmpty ? svcText : 'Appointment',
                  style: const TextStyle(fontSize: 13, color: Colors.white60)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtTime(at), style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: -0.5)),
            Text('$dur min', style: const TextStyle(
                fontSize: 12, color: Colors.white54)),
          ]),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BarberAppointmentsScreen())),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _kBlue, borderRadius: BorderRadius.circular(22)),
                child: const Center(child: Text('Open', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(width: 10),
            _darkIconBtn(Icons.chat_bubble_outline_rounded),
            const SizedBox(width: 8),
            _darkIconBtn(Icons.phone_outlined),
          ],
        ]),
      ]),
    );
  }

  Widget _darkIconBtn(IconData icon) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Icon(icon, size: 18, color: Colors.white),
  );

  // ── Upcoming Section ──────────────────────────────────────────────────────────
  Widget _buildUpcomingSection() {
    final list = _restAppointments;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          Text('Upcoming', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: context.kText, letterSpacing: -0.3)),
          if (list.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(10)),
              child: Text('${list.length}', style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BarberAppointmentsScreen())),
            child: const Text('See all', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kBlue)),
          ),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.kBorder),
            ),
            child: const Center(child: Text('No more appointments today',
                style: TextStyle(fontSize: 14, color: _kGrey, fontWeight: FontWeight.w500))),
          )
        else
          ...list.take(5).map(_buildApptCard),
      ]),
    );
  }

  Widget _buildApptCard(Map<String, dynamic> a) {
    final at    = DateTime.parse(a['scheduledAt'].toString()).toLocal();
    final cust  = a['customer'] as Map? ?? {};
    final name  = (cust['fullName'] as String?) ?? 'Customer';
    final svcs  = (a['services']   as List? ?? []).cast<Map<String, dynamic>>();
    final svc   = svcs.isNotEmpty ? (svcs.first['name'] as String?) ?? '' : '';
    final price = (a['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0';
    final status = a['status'] as String? ?? 'confirmed';
    final inits  = _customerInitials(name);

    final (statusColor, statusLabel) = switch (status) {
      'confirmed' => (const Color(0xFF22C55E), 'Confirmed'),
      'pending'   => (const Color(0xFFF59E0B), 'Pending'),
      'cancelled' => (const Color(0xFFEF4444), 'Cancelled'),
      _           => (const Color(0xFF6B7280), status),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: Center(child: Text(inits, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _kBlue))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: context.kText)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              '${svc.isNotEmpty ? svc : 'Appointment'} · ${_fmtTime(at)} · \$$price',
              style: const TextStyle(fontSize: 12, color: _kGrey),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: _kGrey, size: 18),
      ]),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const tabs = [
      (icon: Icons.home_rounded,             label: 'Home'),
      (icon: Icons.calendar_today_rounded,    label: 'Schedule'),
      (icon: Icons.event_note_rounded,        label: 'Bookings'),
      (icon: Icons.star_outline_rounded,      label: 'Reviews'),
      (icon: Icons.person_outline_rounded,    label: 'Profile'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final i   = e.key;
              final tab = e.value;
              final sel = _navIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    setState(() => _navIndex = i);
                    if (i == 1) {
                      await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BarberScheduleScreen()));
                    } else if (i == 2) {
                      await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BarberAppointmentsScreen()));
                    } else if (i == 3) {
                      await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BarberReviewsScreen()));
                    } else if (i == 4) {
                      await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BarberProfileScreen()));
                    }
                    if (mounted) setState(() => _navIndex = 0);
                  },
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(tab.icon, size: 22,
                        color: sel ? _kBlue : const Color(0xFFBBBBBB)),
                    const SizedBox(height: 3),
                    Text(tab.label, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: sel ? _kBlue : const Color(0xFFBBBBBB))),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
}
