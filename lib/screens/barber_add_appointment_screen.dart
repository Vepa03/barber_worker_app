import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';

class BarberAddAppointmentScreen extends StatefulWidget {
  const BarberAddAppointmentScreen({super.key});

  @override
  State<BarberAddAppointmentScreen> createState() =>
      _BarberAddAppointmentScreenState();
}

class _BarberAddAppointmentScreenState
    extends State<BarberAddAppointmentScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _services = [];
  Set<String> _selectedIds = {};
  Map<String, String> _workingHours = {};
  String? _barberId;
  bool _loadingData = true;
  bool _isSaving = false;

  DateTime? _selectedDay;
  String?   _selectedSlot;
  bool      _loadingSlots = false;
  List<({int startMin, int endMin})> _busyRanges = [];

  static const _dayKeys = [
    'monday','tuesday','wednesday','thursday','friday','saturday','sunday',
  ];
  static const _dayLabels = ['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'];
  static const _months = [
    '','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile =
          await ApiClient.get('/barbers/me') as Map<String, dynamic>;
      if (profile['profileComplete'] != true) {
        if (mounted) setState(() => _loadingData = false);
        return;
      }
      final svcs = (profile['services'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final wh = (profile['workingHours'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final hours = <String, String>{};
      for (final h in wh) {
        final day = h['day'] as String;
        final closed = h['isClosed'] as bool? ?? false;
        if (!closed) {
          final open  = (h['openTime']  as String?)?.substring(0, 5) ?? '';
          final close = (h['closeTime'] as String?)?.substring(0, 5) ?? '';
          hours[day] = '$open – $close';
        } else {
          hours[day] = 'Closed';
        }
      }

      if (mounted) {
        setState(() {
          _services     = svcs;
          _workingHours = hours;
          _barberId     = profile['barberId'] as String?;
          _loadingData  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  // ── Slots ──────────────────────────────────────────────────────────────────
  int get _totalDuration =>
      _services
          .where((s) => _selectedIds.contains(s['id']))
          .fold(0, (sum, s) => sum + ((s['durationMin'] as num?)?.toInt() ?? 30));

  bool _isClosed(DateTime day) {
    final key = _dayKeys[day.weekday - 1];
    final info = _workingHours[key];
    return info == null || info == 'Closed';
  }

  List<String> _slotsFor(DateTime day) {
    final key  = _dayKeys[day.weekday - 1];
    final info = _workingHours[key];
    if (info == null || info == 'Closed') return [];
    final parts = info.split('–');
    if (parts.length < 2) return [];
    final open  = _parseTime(parts[0].trim());
    final close = _parseTime(parts[1].trim());
    if (open == null || close == null) return [];
    final dur = _totalDuration > 0 ? _totalDuration : 30;
    final slots = <String>[];
    var cur = open.hour * 60 + open.minute;
    final end = close.hour * 60 + close.minute;
    while (cur + dur <= end) {
      final h = cur ~/ 60;
      final m = cur % 60;
      slots.add('${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}');
      cur += dur;
    }
    return slots;
  }

  TimeOfDay? _parseTime(String s) {
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _selectDay(DateTime day) async {
    setState(() {
      _selectedDay  = day;
      _selectedSlot = null;
      _busyRanges   = [];
      _loadingSlots = true;
    });
    if (_barberId == null) {
      setState(() => _loadingSlots = false);
      return;
    }
    try {
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final data = await ApiClient.get(
          '/barbers/$_barberId/busy-slots?date=$dateStr') as List;
      final ranges = data.map<({int startMin, int endMin})>((item) {
        final m = item as Map<String, dynamic>;
        final start = DateTime.parse(m['startUtc'] as String).toLocal();
        final startMin = start.hour * 60 + start.minute;
        final endMin = startMin + (m['durationMin'] as int);
        return (startMin: startMin, endMin: endMin);
      }).toList();
      if (mounted) setState(() { _busyRanges = ranges; _loadingSlots = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  bool _isSlotBusy(String slot) {
    final parts     = slot.split(':');
    final slotStart = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final dur       = _totalDuration > 0 ? _totalDuration : 30;
    final slotEnd   = slotStart + dur;
    for (final r in _busyRanges) {
      if (slotStart < r.endMin && slotEnd > r.startMin) return true;
    }
    return false;
  }

  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(60, (i) => today.add(Duration(days: i)));
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedIds.isEmpty) {
      _showError('Lütfen en az bir hizmet seçin.');
      return;
    }
    if (_selectedDay == null || _selectedSlot == null) {
      _showError('Lütfen tarih ve saat seçin.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final parts = _selectedSlot!.split(':');
      final dt = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      await ApiClient.post('/barbers/me/appointments', {
        'scheduledAt': dt.toUtc().toIso8601String(),
        'serviceIds':  _selectedIds.toList(),
        if (_nameCtrl.text.trim().isNotEmpty)
          'customerName': _nameCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'customerPhone': _phoneCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Randevu Ekle'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppTheme.primary))
                : TextButton(
                    onPressed: _save,
                    child: const Text('Kaydet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontSize: 15))),
          ),
        ],
      ),
      body: _loadingData
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2.5))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Müşteri Bilgileri (isteğe bağlı)',
                      child: Column(children: [
                        _buildField(_nameCtrl, 'Ad Soyad',
                            Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                        _buildField(_phoneCtrl, 'Telefon',
                            Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            formatter: FilteringTextInputFormatter.digitsOnly),
                      ])),
                  const SizedBox(height: 20),
                  _buildSection('Hizmetler',
                      child: _services.isEmpty
                          ? const Text(
                              'Önce profilinize hizmet ekleyin.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            )
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: _services.map((s) {
                                final id = s['id'] as String;
                                final sel = _selectedIds.contains(id);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    if (sel) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                    _selectedSlot = null;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppTheme.primary
                                          : AppTheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sel
                                            ? AppTheme.primary
                                            : AppTheme.divider,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(s['icon'] as String? ?? '✂️',
                                            style: const TextStyle(
                                                fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s['name'] as String,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: sel
                                                        ? Colors.white
                                                        : AppTheme
                                                            .textPrimary)),
                                            Text(
                                              '₺${(s['price'] as num).toStringAsFixed(0)} · ${s['durationMin']} dk',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: sel
                                                      ? Colors.white70
                                                      : AppTheme
                                                          .textTertiary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            )),
                  const SizedBox(height: 20),
                  _buildSection('Tarih',
                      child: SizedBox(
                        height: 76,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _days.map((day) {
                            final closed = _isClosed(day);
                            final sel = _selectedDay != null &&
                                _selectedDay!.day == day.day &&
                                _selectedDay!.month == day.month;
                            return GestureDetector(
                              onTap: closed ? null : () => _selectDay(day),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 56,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppTheme.primary
                                      : closed
                                          ? AppTheme.background
                                          : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: sel
                                          ? AppTheme.primary
                                          : AppTheme.divider),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _dayLabels[day.weekday - 1],
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: sel
                                              ? Colors.white
                                              : closed
                                                  ? AppTheme.textTertiary
                                                  : AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: sel
                                              ? Colors.white
                                              : closed
                                                  ? AppTheme.textTertiary
                                                  : AppTheme.textPrimary),
                                    ),
                                    Text(
                                      _months[day.month],
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: sel
                                              ? Colors.white70
                                              : AppTheme.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )),
                  if (_selectedDay != null) ...[
                    const SizedBox(height: 20),
                    _buildSection('Saat',
                        child: _loadingSlots
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.primary,
                                      strokeWidth: 2.5),
                                ),
                              )
                            : Builder(builder: (_) {
                                final available = _slotsFor(_selectedDay!)
                                    .where((s) => !_isSlotBusy(s))
                                    .toList();
                                if (available.isEmpty) {
                                  return const Text(
                                      'Bu gün için uygun saat yok.',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary));
                                }
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: available.map((slot) {
                                    final sel = _selectedSlot == slot;
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedSlot = slot),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? AppTheme.primary
                                              : AppTheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: sel
                                                  ? AppTheme.primary
                                                  : AppTheme.divider,
                                              width: 1.5),
                                        ),
                                        child: Text(slot,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: sel
                                                    ? Colors.white
                                                    : AppTheme.textPrimary)),
                                      ),
                                    );
                                  }).toList(),
                                );
                              })),
                  ],
                  const SizedBox(height: 20),
                  _buildSection('Not (isteğe bağlı)',
                      child: _buildField(
                          _notesCtrl, 'Notunuz…', Icons.notes_rounded,
                          maxLines: 3)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextInputFormatter? formatter,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: formatter != null ? [formatter] : null,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon:
              Icon(icon, size: 18, color: AppTheme.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
