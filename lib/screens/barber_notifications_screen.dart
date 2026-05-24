import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../utils/theme_ext.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGrey   = Color(0xFF8E8E93);
const _kBlue   = Color(0xFF3875F6);
const _kBlueBg = Color(0xFFDCEBFE);

// ── Notification model ────────────────────────────────────────────────────────
enum _NType { booking, review }

class _Notif {
  final String id;
  final _NType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final int? stars;          // for reviews
  final Map<String, dynamic>? appt; // for bookings
  bool read;

  _Notif({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    this.stars,
    this.appt,
    this.read = false,
  });
}

class BarberNotificationsScreen extends StatefulWidget {
  const BarberNotificationsScreen({super.key});
  @override
  State<BarberNotificationsScreen> createState() =>
      _BarberNotificationsScreenState();
}

class _BarberNotificationsScreenState
    extends State<BarberNotificationsScreen> {
  List<_Notif> _notifs = [];
  bool _loading = true;
  Set<String> _readIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _readIds = prefs.getStringList('notif_read')?.toSet() ?? {};
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.get('/barbers/me/appointments'),
        ApiClient.get('/barbers/me/reviews'),
      ]);

      final appts   = (results[0] as List).cast<Map<String, dynamic>>();
      final reviews = (results[1] as List).cast<Map<String, dynamic>>();
      final list    = <_Notif>[];

      // Pending appointments → booking request notifications
      for (final a in appts) {
        if (a['status'] != 'pending') continue;
        final cust    = a['customer'] as Map? ?? {};
        final name    = (cust['fullName'] as String?) ?? 'Customer';
        final svcs    = (a['services'] as List? ?? []).cast<Map<String, dynamic>>();
        final svc     = svcs.isNotEmpty ? (svcs.first['name'] as String?) ?? '' : '';
        final at      = DateTime.tryParse(a['scheduledAt'].toString())?.toLocal()
            ?? DateTime.now();
        final created = DateTime.tryParse(a['createdAt']?.toString() ?? '')
            ?.toLocal() ?? at;
        final timeStr =
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

        list.add(_Notif(
          id:       'appt_${a['id']}',
          type:     _NType.booking,
          title:    'New booking request',
          subtitle: '$name — $svc, ${_dayLabel(at)} $timeStr',
          date:     created,
          appt:     a,
          read:     _readIds.contains('appt_${a['id']}'),
        ));
      }

      // Reviews → review notifications
      for (final r in reviews) {
        final name    = (r['authorName'] as String?) ?? 'Customer';
        final rating  = (r['rating'] as num?)?.toInt() ?? 5;
        final created = DateTime.tryParse(r['createdAt']?.toString() ?? '')
            ?.toLocal() ?? DateTime.now();
        final comment = (r['comment'] as String?) ?? '';

        list.add(_Notif(
          id:       'rev_${r['id']}',
          type:     _NType.review,
          title:    'New $rating-star review',
          subtitle: comment.isNotEmpty
              ? '$name: "$comment"'
              : '$name left you a review',
          date:     created,
          stars:    rating,
          read:     _readIds.contains('rev_${r['id']}'),
        ));
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) setState(() => _notifs = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _notifs) { n.read = true; }
      _readIds = _notifs.map((n) => n.id).toSet();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notif_read', _readIds.toList());
  }

  Future<void> _markRead(String id) async {
    _readIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notif_read', _readIds.toList());
  }

  Future<void> _acceptBooking(_Notif n) async {
    final id = n.appt?['id'] as String? ?? '';
    try {
      await ApiClient.patch(
          '/barbers/me/appointments/$id/status', {'status': 'confirmed'});
      _markRead(n.id);
      _load();
      _snack('✅ Booking accepted');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _declineBooking(_Notif n) async {
    final id = n.appt?['id'] as String? ?? '';
    try {
      await ApiClient.patch(
          '/barbers/me/appointments/$id/status', {'status': 'cancelled'});
      _markRead(n.id);
      _load();
      _snack('Booking declined');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => !n.read).length;
    return Scaffold(
      backgroundColor: context.kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(unread),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: _kBlue, strokeWidth: 2.5))
                : _notifs.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _notifs.length,
                      itemBuilder: (_, i) => _buildCard(_notifs[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(int unread) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Row(children: [
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
        child: Text('Notifications', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: context.kText, letterSpacing: -0.4)),
      ),
      if (unread > 0)
        GestureDetector(
          onTap: _markAllRead,
          child: const Text('Mark all read', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _kBlue)),
        ),
    ]),
  );

  // ── Card ──────────────────────────────────────────────────────────────────────
  Widget _buildCard(_Notif n) {
    final isBooking = n.type == _NType.booking;
    final unread    = !n.read;

    return GestureDetector(
      onTap: () {
        if (unread) {
          setState(() => n.read = true);
          _markRead(n.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? _kBlueBg : context.kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread ? _kBlue.withValues(alpha: 0.35) : context.kBorder,
            width: unread ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _iconColor(n),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconData(n), size: 22, color: context.kSurface),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(n.title, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: context.kText)),
                const SizedBox(height: 3),
                Text(n.subtitle, style: const TextStyle(
                    fontSize: 13, color: _kGrey, height: 1.4)),
              ]),
            ),
            const SizedBox(width: 8),
            // Time
            Text(_timeAgo(n.date), style: const TextStyle(
                fontSize: 12, color: _kGrey)),
          ]),
          // Accept/Decline buttons for pending bookings
          if (isBooking) ...[
            const SizedBox(height: 12),
            Row(children: [
              // Decline
              GestureDetector(
                onTap: () => _declineBooking(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.kBorder, width: 1.5),
                  ),
                  child: Text('Decline', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: context.kText)),
                ),
              ),
              const SizedBox(width: 10),
              // Accept
              GestureDetector(
                onTap: () => _acceptBooking(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Accept', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: context.kSurface)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🔔', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 14),
      Text('No notifications', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: context.kText)),
      const SizedBox(height: 6),
      const Text('You\'re all caught up!',
          style: TextStyle(fontSize: 13, color: _kGrey)),
    ]),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────────
  static Color _iconColor(_Notif n) {
    if (n.type == _NType.booking) return _kBlue;
    final s = n.stars ?? 5;
    return s >= 4 ? const Color(0xFFF59E0B) : const Color(0xFF8E8E93);
  }

  static IconData _iconData(_Notif n) {
    if (n.type == _NType.booking) return Icons.calendar_month_rounded;
    return Icons.star_rounded;
  }

  static String _dayLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[dt.month-1]} ${dt.day}';
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60)  return '${d.inMinutes}m';
    if (d.inHours   < 24)  return '${d.inHours}h';
    if (d.inDays    < 7)   return '${d.inDays}d';
    return '${d.inDays ~/ 7}w';
  }
}
