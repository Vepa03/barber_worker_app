import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import 'barber_add_appointment_screen.dart';
import 'barber_appointment_detail_screen.dart';
import 'barber_login_screen.dart';
import '../utils/theme_ext.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const _kGrey   = Color(0xFF8E8E93);
const _kBlue   = Color(0xFF3875F6);

class BarberAppointmentsScreen extends StatefulWidget {
  const BarberAppointmentsScreen({super.key});
  @override
  State<BarberAppointmentsScreen> createState() => _BarberAppointmentsScreenState();
}

class _BarberAppointmentsScreenState extends State<BarberAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  bool _searching = false;
  String _query   = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  static const _tabLabels = ['Upcoming', 'Past'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/barbers/me/appointments') as List;
      if (mounted) setState(() => _all = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        await AuthStorage.clearTokens();
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const BarberLoginScreen()),
            (_) => false);
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Filtering ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _forTab(int idx) {
    final now = DateTime.now();
    List<Map<String, dynamic>> result;

    switch (idx) {
      case 0: // Upcoming: future & not cancelled
        result = _all.where((a) {
          final at = DateTime.tryParse(a['scheduledAt'].toString())?.toLocal();
          return at != null && at.isAfter(now) && a['status'] != 'cancelled';
        }).toList()
          ..sort((a, b) => DateTime.parse(a['scheduledAt'].toString())
              .compareTo(DateTime.parse(b['scheduledAt'].toString())));
      default: // Past: in the past or cancelled/completed
        result = _all.where((a) {
          final at    = DateTime.tryParse(a['scheduledAt'].toString())?.toLocal();
          final st    = a['status'] as String? ?? '';
          final isPast = at != null && at.isBefore(now);
          return isPast || st == 'cancelled' || st == 'completed';
        }).toList()
          ..sort((a, b) => DateTime.parse(b['scheduledAt'].toString())
              .compareTo(DateTime.parse(a['scheduledAt'].toString())));
    }
    // Apply search filter
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result.where((a) {
        final cust = a['customer'] as Map? ?? {};
        final name = (cust['fullName'] as String? ?? '').toLowerCase();
        final phone = (cust['phone'] as String? ?? '').toLowerCase();
        final svcs = (a['services'] as List? ?? []).cast<Map<String, dynamic>>();
        final svcNames = svcs
            .map((s) => (s['name'] as String? ?? '').toLowerCase())
            .join(' ');
        return name.contains(q) || phone.contains(q) || svcNames.contains(q);
      }).toList();
    }
    return result;
  }

  // ── Search toggle ─────────────────────────────────────────────────────────────
  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchCtrl.clear();
      }
    });
    if (_searching) {
      Future.delayed(const Duration(milliseconds: 80),
          () => _searchFocus.requestFocus());
    }
  }

  // ── Grouping ──────────────────────────────────────────────────────────────────
  List<_Group> _grouped(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final a in items) {
      final dt  = DateTime.parse(a['scheduledAt'].toString()).toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return (map.keys.toList()..sort()).map((k) {
      final dt = DateTime.parse(k);
      return _Group(date: dt, items: map[k]!);
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
                : TabBarView(
                    controller: _tab,
                    children: List.generate(2, (i) => _buildList(i)),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: context.kSurface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.kBorder),
            ),
            child: Icon(Icons.chevron_left, size: 20, color: context.kText),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Appointments', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: context.kText, letterSpacing: -0.5)),
        ),
        GestureDetector(
          onTap: () async {
            final ok = await Navigator.push<bool>(context,
                MaterialPageRoute(
                    builder: (_) => const BarberAddAppointmentScreen()));
            if (ok == true) _load();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: context.kSurface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.kBorder),
            ),
            child: Icon(Icons.add_rounded, size: 20, color: context.kText),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleSearch,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _searching ? _kBlue : context.kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _searching ? _kBlue : context.kBorder),
            ),
            child: Icon(
              _searching ? Icons.close_rounded : Icons.search_rounded,
              size: 20,
              color: _searching ? context.kSurface : context.kText,
            ),
          ),
        ),
      ]),
      // ── Search field ─────────────────────────────────────────────────────
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: _searching
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: const SizedBox(height: 0),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBlue, width: 1.5),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.search_rounded, size: 18, color: _kGrey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: TextStyle(fontSize: 15, color: context.kText),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or service...',
                    hintStyle: TextStyle(fontSize: 14, color: _kGrey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _query = '';
                    _searchCtrl.clear();
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.cancel_rounded,
                        size: 18, color: _kGrey),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]),
  );

  // ── Pill tabs ─────────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(2, (i) {
            final sel = _tab.index == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _tab.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: sel ? context.kSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: sel ? [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6, offset: const Offset(0, 2),
                    )] : null,
                  ),
                  child: Center(
                    child: Text(_tabLabels[i], style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? context.kText : _kGrey)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────────
  Widget _buildList(int tabIdx) {
    final items  = _forTab(tabIdx);
    if (items.isEmpty) return _EmptyView(tabLabels: _tabLabels[tabIdx]);

    final groups = _grouped(items);
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: groups.length,
        itemBuilder: (_, i) => _buildGroup(groups[i]),
      ),
    );
  }

  Widget _buildGroup(_Group g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(_sectionLabel(g.date), style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGrey, letterSpacing: 0.6)),
        ),
        ...g.items.map((a) => _ApptCard(appt: a, onRefresh: _load)),
      ],
    );
  }

  static String _sectionLabel(DateTime dt) {
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d        = DateTime(dt.year, dt.month, dt.day);
    if (d == today)    return 'TODAY';
    if (d == tomorrow) return 'TOMORROW';
    const days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    const mos  = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${days[dt.weekday-1]}, ${mos[dt.month-1]} ${dt.day}';
  }
}

// ── Group model ───────────────────────────────────────────────────────────────
class _Group {
  final DateTime date;
  final List<Map<String, dynamic>> items;
  const _Group({required this.date, required this.items});
}

// ── Appointment Card ──────────────────────────────────────────────────────────
class _ApptCard extends StatelessWidget {
  final Map<String, dynamic> appt;
  final VoidCallback onRefresh;
  const _ApptCard({required this.appt, required this.onRefresh});

  static const _avatarColors = [
    Color(0xFF3875F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF22C55E),
  ];

  Color _avatarColor(String name) {
    if (name.isEmpty) return _kBlue;
    int h = 0;
    for (final c in name.runes) { h = (h * 31 + c) & 0xFFFFFFFF; }
    return _avatarColors[h % _avatarColors.length];
  }

  static (Color, String) _statusStyle(String status, DateTime at, int dur) {
    final now = DateTime.now();
    final end = at.add(Duration(minutes: dur));
    String s = status;
    if (status == 'confirmed' && now.isAfter(end)) s = 'completed';
    if (status == 'confirmed' && now.isAfter(at) && now.isBefore(end)) s = 'in_progress';

    return switch (s) {
      'confirmed'   => (const Color(0xFF22C55E), 'Confirmed'),
      'pending'     => (const Color(0xFFF59E0B), 'Pending'),
      'in_progress' => (const Color(0xFF3875F6), 'In Progress'),
      'completed'   => (const Color(0xFF8E8E93), 'Completed'),
      'cancelled'   => (const Color(0xFFEF4444), 'Cancelled'),
      _             => (const Color(0xFF8E8E93), s),
    };
  }

  static String _ini(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final at     = DateTime.parse(appt['scheduledAt'].toString()).toLocal();
    final dur    = (appt['totalDurationMin'] as int?) ?? 0;
    final cust   = appt['customer'] as Map? ?? {};
    final name   = (cust['fullName'] as String?) ?? '';
    final phone  = (cust['phone']    as String?) ?? '';
    final svcs   = (appt['services'] as List? ?? []).cast<Map<String, dynamic>>();
    final status = appt['status'] as String? ?? 'confirmed';

    final svcText = svcs.map((s) => s['name'] as String? ?? '').join(' + ');
    final timeStr = '${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')}';
    final durStr  = dur >= 60
        ? '${dur ~/ 60}h${dur % 60 > 0 ? ' ${dur % 60}m' : ''}'
        : '${dur}m';
    final ini    = _ini(name.isNotEmpty ? name : phone);
    final aColor = _avatarColor(name.isNotEmpty ? name : phone);
    final (stColor, stLabel) = _statusStyle(status, at, dur);

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) =>
              BarberAppointmentDetailScreen(appt: appt)),
        );
        if (changed == true) onRefresh();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: context.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          // ── Time ───────────────────────────────────────────────────────────
          SizedBox(
            width: 54,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(timeStr, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: context.kText, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(durStr, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey)),
            ]),
          ),
          const SizedBox(width: 12),
          // ── Avatar ─────────────────────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: aColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(ini, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: aColor))),
          ),
          const SizedBox(width: 12),
          // ── Name + service ─────────────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isNotEmpty ? name : phone,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: context.kText),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (svcText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(svcText, style: const TextStyle(
                    fontSize: 12, color: _kGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('tel:$phone'),
                      mode: LaunchMode.externalApplication),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone_rounded, size: 11, color: _kGrey),
                    const SizedBox(width: 3),
                    Text(phone, style: const TextStyle(fontSize: 11, color: _kGrey)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          // ── Status badge ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: stColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(stLabel, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: stColor)),
          ),
        ]),
      ),
    ));
  }
}

// ── Empty view ────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String tabLabels;
  const _EmptyView({required this.tabLabels});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📅', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 14),
      Text('No $tabLabels appointments', style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey)),
    ]),
  );
}
