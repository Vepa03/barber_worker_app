import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import 'barber_add_appointment_screen.dart';
import 'barber_login_screen.dart';
import '../utils/theme_ext.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const _kGrey   = Color(0xFF888888);
const _kBlue   = Color(0xFF3875F6);
const _kBlueSoft = Color(0xFFEBF2FE);

const _kStartHour = 8;
const _kEndHour   = 20;
const _kHourH     = 64.0;   // pixels per hour
const _kTimeColW  = 40.0;   // left time label column width

class BarberScheduleScreen extends StatefulWidget {
  const BarberScheduleScreen({super.key});
  @override
  State<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<BarberScheduleScreen> {
  bool   _weekView    = true;
  late   DateTime _weekStart;    // always a Monday
  late   DateTime _selectedDay;
  List<Map<String, dynamic>> _appointments = [];
  bool   _loading = true;

  @override
  void initState() {
    super.initState();
    final now    = DateTime.now();
    _weekStart   = _monday(now);
    _selectedDay = now;
    _load();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/barbers/me/appointments') as List;
      if (mounted) setState(() => _appointments = data.cast<Map<String, dynamic>>());
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

  List<Map<String, dynamic>> _apptForDay(DateTime day) =>
      _appointments.where((a) {
        final at = DateTime.tryParse(a['scheduledAt'].toString())?.toLocal();
        return at != null && _sameDay(at, day) && a['status'] != 'cancelled';
      }).toList();

  // ── Week navigation ───────────────────────────────────────────────────────────
  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  String _weekLabel() {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final e  = _weekStart.add(const Duration(days: 6));
    return '${mo[_weekStart.month-1]} ${_weekStart.day} — ${mo[e.month-1]} ${e.day}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            _buildWeekNav(),
            if (_weekView) _buildDayHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5))
                  : _weekView ? _buildWeekGrid() : _buildDayGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: context.kBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.kBorder),
          ),
          child: Icon(Icons.chevron_left, size: 20, color: context.kText),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text('Time table', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: context.kText, letterSpacing: -0.5)),
      ),
      _topBtn(Icons.tune_rounded, () {}),
      const SizedBox(width: 8),
      _topBtn(Icons.add_rounded, () async {
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const BarberAddAppointmentScreen()),
        );
        if (ok == true) _load();
      }),
    ]),
  );

  Widget _topBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: context.kBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.kBorder),
      ),
      child: Icon(icon, size: 18, color: context.kText),
    ),
  );

  // ── Week nav row ──────────────────────────────────────────────────────────────
  Widget _buildWeekNav() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Week of', style: TextStyle(fontSize: 11, color: _kGrey, fontWeight: FontWeight.w500)),
        Row(children: [
          Text(_weekLabel(), style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: context.kText)),
          const SizedBox(width: 4),
          GestureDetector(onTap: _prevWeek,
              child: const Icon(Icons.chevron_left_rounded, size: 18, color: _kGrey)),
          GestureDetector(onTap: _nextWeek,
              child: const Icon(Icons.chevron_right_rounded, size: 18, color: _kGrey)),
        ]),
      ]),
      const Spacer(),
      // Day / Week pill toggle
      Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _pillBtn('Day',  !_weekView, () => setState(() { _weekView = false; })),
          _pillBtn('Week',  _weekView, () => setState(() { _weekView = true;  })),
        ]),
      ),
    ]),
  );

  Widget _pillBtn(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? context.kSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? context.kText : _kGrey)),
        ),
      );

  // ── Day header (week view only) ───────────────────────────────────────────────
  Widget _buildDayHeader() {
    const letters = ['M','T','W','T','F','S','S'];
    final today = DateTime.now();
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.kBorder))),
      child: Row(children: [
        const SizedBox(width: _kTimeColW),
        ...List.generate(7, (i) {
          final day = _weekStart.add(Duration(days: i));
          final isTd = _sameDay(day, today);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _selectedDay = day; _weekView = false; }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Text(letters[i], style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isTd ? _kBlue : _kGrey)),
                  const SizedBox(height: 3),
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isTd ? _kBlue : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${day.day}', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isTd ? context.kSurface : context.kText))),
                  ),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ── Week grid ─────────────────────────────────────────────────────────────────
  Widget _buildWeekGrid() {
    final totalH = (_kEndHour - _kStartHour) * _kHourH;
    final now    = DateTime.now();

    return LayoutBuilder(builder: (_, constraints) {
      final colW = (constraints.maxWidth - _kTimeColW) / 7;

      return RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: totalH + 16,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time labels
                  SizedBox(
                    width: _kTimeColW,
                    height: totalH,
                    child: Stack(
                      children: List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                        top: i * _kHourH - 7,
                        left: 0, right: 4,
                        child: Text('${_kStartHour + i}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10,
                                color: _kGrey, fontWeight: FontWeight.w500)),
                      )),
                    ),
                  ),
                  // Day columns
                  ...List.generate(7, (dayIdx) {
                    final day   = _weekStart.add(Duration(days: dayIdx));
                    final isTd  = _sameDay(day, now);
                    final appts = _apptForDay(day);

                    return SizedBox(
                      width: colW,
                      height: totalH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isTd ? _kBlue.withValues(alpha: 0.02) : null,
                          border: Border(
                              left: BorderSide(color: context.kBorder, width: 0.5)),
                        ),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            // Hour dividers
                            ...List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                              top: i * _kHourH, left: 0, right: 0,
                              child: Container(height: 0.5, color: context.kBorder),
                            )),
                            // Half-hour dividers (lighter)
                            ...List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                              top: i * _kHourH + _kHourH / 2, left: 0, right: 0,
                              child: Container(height: 0.5,
                                  color: context.kBorder.withValues(alpha: 0.5)),
                            )),
                            // Current time line
                            if (isTd && now.hour >= _kStartHour && now.hour < _kEndHour)
                              Positioned(
                                top: _tOffset(now), left: 0, right: 0,
                                child: Row(children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                        color: Colors.redAccent, shape: BoxShape.circle),
                                  ),
                                  Expanded(child: Container(
                                      height: 1.5, color: Colors.redAccent)),
                                ]),
                              ),
                            // Appointments
                            ...appts.map((a) => _weekBlock(a, isTd, colW)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _weekBlock(Map<String, dynamic> a, bool isToday, double colW) {
    final at   = DateTime.parse(a['scheduledAt'].toString()).toLocal();
    final dur  = (a['totalDurationMin'] as int?) ?? 30;
    final top  = _tOffset(at);
    final h    = max((dur / 60) * _kHourH, 24.0);
    final name = (a['customer'] as Map?)?['fullName'] as String? ?? '';
    final svcs = (a['services'] as List? ?? []).cast<Map<String, dynamic>>();
    final svc  = svcs.isNotEmpty ? (svcs.first['name'] as String?) ?? '' : '';
    final ini  = _ini(name);

    return Positioned(
      top: top + 1, left: 2, right: 2,
      height: h - 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isToday ? _kBlue : context.kSurface,
          borderRadius: BorderRadius.circular(6),
          border: isToday ? null : Border.all(color: const Color(0xFFD0D0D0)),
          boxShadow: isToday ? null : [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ini, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, height: 1.1,
                color: isToday ? context.kSurface : context.kText)),
            if (svc.isNotEmpty && h > 38)
              Text(svc.split(' ').first, style: TextStyle(
                  fontSize: 9, height: 1.1,
                  color: isToday ? Colors.white60 : _kGrey),
                  maxLines: 1, overflow: TextOverflow.clip),
          ],
        ),
      ),
    );
  }

  // ── Day grid ──────────────────────────────────────────────────────────────────
  Widget _buildDayGrid() {
    final totalH = (_kEndHour - _kStartHour) * _kHourH;
    final now    = DateTime.now();
    final isTd   = _sameDay(_selectedDay, now);
    final appts  = _apptForDay(_selectedDay);

    return Column(children: [
      _buildDayStrip(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _kBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              height: totalH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time labels
                  SizedBox(
                    width: _kTimeColW,
                    height: totalH,
                    child: Stack(
                      children: List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                        top: i * _kHourH - 7, left: 0, right: 4,
                        child: Text('${_kStartHour + i}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10,
                                color: _kGrey, fontWeight: FontWeight.w500)),
                      )),
                    ),
                  ),
                  // Single day column
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Hour lines
                        ...List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                          top: i * _kHourH, left: 0, right: 0,
                          child: Container(height: 0.5, color: context.kBorder),
                        )),
                        // Half-hour lines
                        ...List.generate(_kEndHour - _kStartHour, (i) => Positioned(
                          top: i * _kHourH + _kHourH / 2, left: 0, right: 0,
                          child: Container(height: 0.5,
                              color: context.kBorder.withValues(alpha: 0.5)),
                        )),
                        // Current time
                        if (isTd && now.hour >= _kStartHour && now.hour < _kEndHour)
                          Positioned(
                            top: _tOffset(now), left: 0, right: 0,
                            child: Row(children: [
                              Container(width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: Colors.redAccent, shape: BoxShape.circle)),
                              Expanded(child: Container(height: 1.5, color: Colors.redAccent)),
                            ]),
                          ),
                        // Appointments
                        ...appts.map(_dayBlock),
                        // Empty state
                        if (appts.isEmpty)
                          Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('📅', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              Text('No appointments',
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600,
                                      color: _kGrey)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDayStrip() {
    const letters = ['M','T','W','T','F','S','S'];
    final today   = DateTime.now();
    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 7,
        itemBuilder: (_, i) {
          final d    = _weekStart.add(Duration(days: i));
          final isTd = _sameDay(d, today);
          final isSel = _sameDay(d, _selectedDay);
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSel ? _kBlue : (isTd ? _kBlueSoft : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(letters[i], style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : (isTd ? _kBlue : _kGrey))),
                const SizedBox(height: 2),
                Text('${d.day}', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: isSel ? Colors.white : context.kText)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _dayBlock(Map<String, dynamic> a) {
    final at    = DateTime.parse(a['scheduledAt'].toString()).toLocal();
    final dur   = (a['totalDurationMin'] as int?) ?? 30;
    final top   = _tOffset(at);
    final h     = max((dur / 60) * _kHourH, 52.0);
    final name  = (a['customer'] as Map?)?['fullName'] as String? ?? 'Customer';
    final svcs  = (a['services'] as List? ?? []).cast<Map<String, dynamic>>();
    final svcTx = svcs.map((s) => s['name'] as String? ?? '').join(', ');
    final price = (a['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0';
    final tStr  = '${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')}';
    final ini   = _ini(name);

    return Positioned(
      top: top + 1, left: 4, right: 4,
      height: h - 2,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(ini, style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(tStr, style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
            ]),
            if (svcTx.isNotEmpty && h > 64) ...[
              const SizedBox(height: 4),
              Text(svcTx, style: const TextStyle(
                  fontSize: 11, color: Colors.white70),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (h > 80) ...[
              const Spacer(),
              Text('\$$price', style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  static double _tOffset(DateTime dt) =>
      ((dt.hour - _kStartHour) + dt.minute / 60) * _kHourH;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _monday(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day - (dt.weekday - 1));

  static String _ini(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return (p.isNotEmpty && p[0].isNotEmpty) ? p[0][0].toUpperCase() : '?';
  }
}
