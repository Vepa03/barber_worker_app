import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../utils/theme_ext.dart';

class BarberAppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appt;
  const BarberAppointmentDetailScreen({super.key, required this.appt});

  @override
  State<BarberAppointmentDetailScreen> createState() =>
      _State();
}

class _State extends State<BarberAppointmentDetailScreen> {
  late Map<String, dynamic> _a;
  bool _busy = false;

  // ── Palette ───────────────────────────────────────────────────────────────────
  static const _bg       = Color(0xFFF2F2F7);
  static const _white    = Colors.white;
  static const _black    = Color(0xFF1A1A1A);
  static const _grey     = Color(0xFF8E8E93);
  static const _border   = Color(0xFFEEEEEE);
  static const _blue     = Color(0xFF3875F6);
  static const _green    = Color(0xFF22C55E);
  static const _amber    = Color(0xFFF59E0B);
  static const _red      = Color(0xFFEF4444);

  static const _colors = [
    Color(0xFF3875F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFF22C55E),
  ];

  @override
  void initState() {
    super.initState();
    _a = Map<String, dynamic>.from(widget.appt);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Color _color(String s) {
    int h = 0;
    for (final c in s.runes) { h = (h * 31 + c) & 0xFFFFFFFF; }
    return _colors[h % _colors.length];
  }

  String _ini(String s) {
    final p = s.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  String _when(DateTime dt) {
    final n   = DateTime.now();
    final tod = DateTime(n.year, n.month, n.day);
    final tom = tod.add(const Duration(days: 1));
    final d   = DateTime(dt.year, dt.month, dt.day);
    final t   = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    if (d == tod) return 'Today · $t';
    if (d == tom) return 'Tomorrow · $t';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day} · $t';
  }

  (Color, String) _badge(String s) => switch (s) {
    'confirmed'   => (_green, 'Confirmed'),
    'pending'     => (_amber, 'Pending'),
    'completed'   => (_grey,  'Completed'),
    'cancelled'   => (_red,   'Cancelled'),
    'in_progress' => (_blue,  'In Progress'),
    _             => (_grey,  s),
  };

  bool get _canAct {
    final s = _a['status'] as String? ?? '';
    return s == 'confirmed' || s == 'pending';
  }

  // ── Status update ─────────────────────────────────────────────────────────────
  Future<void> _setStatus(String status) async {
    final id = _a['id'] as String? ?? '';
    setState(() => _busy = true);
    try {
      await ApiClient.patch(
          '/barbers/me/appointments/$id/status', {'status': status});
      if (!mounted) return;
      setState(() => _a = {..._a, 'status': status});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'completed' ? '✅ Tamamlandı' : '❌ İptal edildi'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: status == 'completed' ? _green : _red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancelDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Randevuyu İptal Et',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Bu randevuyu iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Hayır', style: TextStyle(color: _grey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('İptal Et',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) _setStatus('cancelled');
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cust   = _a['customer']  as Map? ?? {};
    final name   = (cust['fullName'] as String?) ?? '';
    final phone  = (cust['phone']   as String?) ?? '';
    final avUrl  = (cust['avatar']  as String?) ?? '';
    final svcs   = (_a['services']  as List? ?? []).cast<Map<String, dynamic>>();
    final at     = DateTime.parse(_a['scheduledAt'].toString()).toLocal();
    final dur    = (_a['totalDurationMin'] as int?) ?? 0;
    final price  = (_a['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0';
    final status = _a['status'] as String? ?? 'confirmed';
    final notes  = (_a['notes']  as String?) ?? '';
    final svcTxt = svcs.map((s) => s['name'] as String? ?? '').join(' + ');
    final disp   = name.isNotEmpty ? name : phone;
    final ini    = _ini(disp);
    final col    = _color(disp);
    final (badgeCol, badgeLbl) = _badge(status);
    final durStr = dur >= 60
        ? '${dur ~/ 60}h ${dur % 60 > 0 ? '${dur % 60} min' : ''}'.trim()
        : '$dur min';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Top nav ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              _iconBtn(Icons.chevron_left, () => Navigator.pop(context)),
              const Expanded(
                child: Text('Appointment', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: _black)),
              ),
              _iconBtn(Icons.description_outlined, () {}),
            ]),
          ),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(children: [

                // ── Avatar ────────────────────────────────────────────────
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col.withValues(alpha: 0.15),
                    image: avUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(avUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: avUrl.isEmpty
                      ? Center(child: Text(ini, style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900, color: col)))
                      : null,
                ),
                const SizedBox(height: 14),

                // ── Name ──────────────────────────────────────────────────
                Text(disp, style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: _black, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(_when(at), style: const TextStyle(
                    fontSize: 13, color: _grey)),
                const SizedBox(height: 18),

                // ── Message / Call ────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _pillBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onTap: phone.isNotEmpty
                        ? () => launchUrl(Uri.parse('sms:$phone'),
                            mode: LaunchMode.externalApplication)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  _pillBtn(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: phone.isNotEmpty
                        ? () => launchUrl(Uri.parse('tel:$phone'),
                            mode: LaunchMode.externalApplication)
                        : null,
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Details card ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10, offset: const Offset(0, 2),
                    )],
                  ),
                  child: Column(children: [
                    _row('When',     _when(at),                    null),
                    _divider(),
                    _row('Service',  svcTxt.isNotEmpty ? svcTxt : '—', null),
                    _divider(),
                    _row('Duration', durStr,                        null),
                    _divider(),
                    _row('Price',    '\$$price',                    null),
                    _divider(),
                    // Status row with badge
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 15),
                      child: Row(children: [
                        const Text('Status', style: TextStyle(
                            fontSize: 15, color: _grey,
                            fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeCol.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(badgeLbl, style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: badgeCol)),
                        ),
                      ]),
                    ),
                  ]),
                ),

                // ── Notes ─────────────────────────────────────────────────
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('NOTES', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _grey.withValues(alpha: 0.8),
                          letterSpacing: 0.7)),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10, offset: const Offset(0, 2),
                      )],
                    ),
                    child: Text(notes, style: const TextStyle(
                        fontSize: 15, color: _black, height: 1.55)),
                  ),
                ],
              ]),
            ),
          ),

          // ── Bottom bar ─────────────────────────────────────────────────────
          if (_canAct)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: _white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(children: [
                // Cancel
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _busy ? null : _cancelDialog,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _border, width: 1.5),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.cancel_outlined, size: 17, color: _black),
                        SizedBox(width: 6),
                        Text('Cancel', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _black)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Mark as complete
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _busy ? null : () => _setStatus('completed'),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: _black,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _busy
                          ? const Center(child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: _white)))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Icon(Icons.check_rounded, size: 18, color: _white),
                            SizedBox(width: 6),
                            Text('Mark as complete', style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: _white)),
                          ]),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  // ── Reusable pieces ───────────────────────────────────────────────────────────
  Widget _row(String label, String value, Color? vColor) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: Row(children: [
      Text(label, style: const TextStyle(
          fontSize: 15, color: _grey, fontWeight: FontWeight.w500)),
      const Spacer(),
      Flexible(
        child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: vColor ?? _black)),
      ),
    ]),
  );

  Widget _divider() =>
      const Divider(height: 1, indent: 18, endIndent: 18, color: _border);

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 20, color: _black),
    ),
  );

  Widget _pillBtn({required IconData icon, required String label, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4, offset: const Offset(0, 1),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: onTap != null ? _black : _grey),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: onTap != null ? _black : _grey)),
          ]),
        ),
      );
}
