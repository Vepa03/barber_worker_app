import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/barber_auth_service.dart';
import '../services/api_client.dart';
import 'waiting_approval_screen.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFFF4F4F4);
const _kBlack  = Color(0xFF1A1A1A);
const _kGrey   = Color(0xFF888888);
const _kGreyL  = Color(0xFFAAAAAA);
const _kBorder = Color(0xFFE8E8E8);
const _kBlue   = Color(0xFF3875F6);
const _kBlueBg = Color(0xFFEBF2FE);

const _kHeadline = TextStyle(
  fontSize: 28, fontWeight: FontWeight.w800,
  color: _kBlack, height: 1.15, letterSpacing: -0.5,
);

// ── Models ────────────────────────────────────────────────────────────────────
class _Service {
  String name, price, duration;
  _Service({required this.name, required this.price, required this.duration});
}

class _DaySchedule {
  final String day;
  bool enabled;
  TimeOfDay start, end;
  _DaySchedule({required this.day, required this.enabled,
      required this.start, required this.end});
}

// ── Screen ────────────────────────────────────────────────────────────────────
class BarberOnboardingScreen extends StatefulWidget {
  final String email;
  final String phone;
  const BarberOnboardingScreen({super.key, required this.email, required this.phone});

  @override
  State<BarberOnboardingScreen> createState() => _BarberOnboardingScreenState();
}

class _BarberOnboardingScreenState extends State<BarberOnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  static const _total = 9;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Step 1 – Name
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();

  // Step 2 – Photos
  File? _coverPhoto;
  File? _profilePhoto;

  // Step 3 – City (backend)
  final _citySearchCtrl = TextEditingController();
  String? _selectedCityId;
  String? _selectedCityName;
  List<Map<String, String>> _cities = [];
  bool _citiesLoading = false;
  String? _citiesError;

  // Step 4 – Work type
  String _venueType = 'barber';
  static const _venueOptions = [
    (type: 'barber',       icon: Icons.content_cut_rounded,      label: 'Barber',   sub: 'Cuts, shaves, beard work'),
    (type: 'womens_salon', icon: Icons.auto_awesome_rounded,      label: 'Salon',    sub: 'Hair, color, styling'),
    (type: 'massage',      icon: Icons.self_improvement_rounded,  label: 'Massage',  sub: 'Therapeutic & relaxation'),
    (type: 'car_wash',     icon: Icons.directions_car_rounded,    label: 'Car wash', sub: 'Detail & quick wash'),
  ];

  // Step 5 – Shop name
  final _shopCtrl    = TextEditingController();
  final _taglineCtrl = TextEditingController();

  // Step 6 – Portfolio
  final List<File?> _portfolio = List.filled(6, null);

  // Step 7 – Bio
  final _yearsCtrl = TextEditingController();
  final _bioCtrl   = TextEditingController();

  // Step 8 – Services
  final List<_Service> _services = [
    _Service(name: 'Classic cut',   price: '35', duration: '30'),
    _Service(name: 'Skin fade',     price: '45', duration: '45'),
    _Service(name: 'Beard line-up', price: '25', duration: '20'),
  ];

  // Step 9 – Schedule
  final List<_DaySchedule> _schedule = [
    _DaySchedule(day: 'Mon', enabled: true,  start: const TimeOfDay(hour: 9,  minute: 0), end: const TimeOfDay(hour: 18, minute: 0)),
    _DaySchedule(day: 'Tue', enabled: true,  start: const TimeOfDay(hour: 9,  minute: 0), end: const TimeOfDay(hour: 18, minute: 0)),
    _DaySchedule(day: 'Wed', enabled: true,  start: const TimeOfDay(hour: 9,  minute: 0), end: const TimeOfDay(hour: 18, minute: 0)),
    _DaySchedule(day: 'Thu', enabled: true,  start: const TimeOfDay(hour: 9,  minute: 0), end: const TimeOfDay(hour: 18, minute: 0)),
    _DaySchedule(day: 'Fri', enabled: true,  start: const TimeOfDay(hour: 9,  minute: 0), end: const TimeOfDay(hour: 20, minute: 0)),
    _DaySchedule(day: 'Sat', enabled: true,  start: const TimeOfDay(hour: 10, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
    _DaySchedule(day: 'Sun', enabled: false, start: const TimeOfDay(hour: 10, minute: 0), end: const TimeOfDay(hour: 16, minute: 0)),
  ];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
    _fetchCities();
  }

  Future<void> _fetchCities() async {
    setState(() { _citiesLoading = true; _citiesError = null; });
    try {
      final data = await ApiClient.get('/cities') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _cities = data.map((c) => {
          'id':   (c as Map<String, dynamic>)['id']   as String,
          'name': c['name'] as String,
        }).toList();
        _citiesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _citiesLoading = false; _citiesError = e.toString(); });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _firstCtrl.dispose(); _lastCtrl.dispose();
    _citySearchCtrl.dispose();
    _shopCtrl.dispose(); _taglineCtrl.dispose();
    _yearsCtrl.dispose(); _bioCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  Future<void> _next() async {
    if (_step < _total - 1) {
      await _anim.reverse();
      setState(() => _step++);
      _anim.forward();
    } else {
      await _submit();
    }
  }

  Future<void> _back() async {
    if (_step > 0) {
      await _anim.reverse();
      setState(() => _step--);
      _anim.forward();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Upload photos concurrently
      final uploads = await Future.wait([
        _coverPhoto   != null ? ApiClient.uploadFile(_coverPhoto!)   : Future.value(null),
        _profilePhoto != null ? ApiClient.uploadFile(_profilePhoto!) : Future.value(null),
      ]);
      final coverUrl   = uploads[0];
      final profileUrl = uploads[1];

      // Upload portfolio
      final portfolioFutures = _portfolio
          .where((f) => f != null)
          .map((f) => ApiClient.uploadFile(f!));
      final portfolioResults = await Future.wait(portfolioFutures);
      final portfolioUrls = portfolioResults.whereType<String>().toList();

      // Build services list
      final services = _services
          .where((s) => s.name.trim().isNotEmpty)
          .map((s) => {'name': s.name.trim(), 'price': s.price, 'duration': s.duration})
          .toList();

      // Build working hours list
      final workingHours = _schedule.map((d) => <String, dynamic>{
        'day':     d.day,
        'enabled': d.enabled,
        'start':   '${d.start.hour.toString().padLeft(2,'0')}:${d.start.minute.toString().padLeft(2,'0')}',
        'end':     '${d.end.hour.toString().padLeft(2,'0')}:${d.end.minute.toString().padLeft(2,'0')}',
      }).toList();

      final years = int.tryParse(_yearsCtrl.text.trim());

      await BarberAuthService.register(
        phone:              '+993${widget.phone}',
        firstName:          _firstCtrl.text.trim(),
        lastName:           _lastCtrl.text.trim(),
        salonName:          _shopCtrl.text.trim(),
        venueType:          _venueType,
        cityId:             _selectedCityId,
        cityName:           _selectedCityName,
        tagline:            _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
        about:              _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        yearsOfExperience:  years,
        services:           services.isEmpty ? null : services,
        workingHours:       workingHours,
        coverPhotoUrl:      coverUrl,
        profilePhotoUrl:    profileUrl,
        portfolioUrls:      portfolioUrls.isEmpty ? null : portfolioUrls,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _firstCtrl.text.trim().isNotEmpty && _lastCtrl.text.trim().isNotEmpty;
      case 1: return _coverPhoto != null && _profilePhoto != null;
      case 2: return _selectedCityId != null;
      case 4: return _shopCtrl.text.trim().isNotEmpty;
      case 7: return _services.isNotEmpty && _services.every((s) =>
          s.name.trim().isNotEmpty && s.price.isNotEmpty && s.duration.isNotEmpty);
      default: return true;
    }
  }

  Future<File?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(position: _slide, child: _buildStep()),
              ),
            ),
            _bottomBtn(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      children: [
        GestureDetector(
          onTap: _back,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder)),
            child: const Icon(Icons.chevron_left, color: _kBlack, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _total,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('${_step + 1}/$_total',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey)),
      ],
    ),
  );

  // ── Bottom button ─────────────────────────────────────────────────────────────
  Widget _bottomBtn() {
    final isLast     = _step == _total - 1;
    final isSkip     = _step == 5 && _portfolio.every((f) => f == null);
    final label      = isLast ? 'Open dashboard' : isSkip ? 'Skip for now' : 'Continue';

    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: GestureDetector(
        onTap: _canProceed ? _next : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: _canProceed ? _kBlack : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(32),
          ),
          child: _submitting
              ? const Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1,
                    color: _canProceed ? Colors.white : const Color(0xFFAAAAAA),
                  )),
                  const SizedBox(width: 6),
                  Icon(Icons.north_east_rounded, size: 18,
                      color: _canProceed ? Colors.white : const Color(0xFFAAAAAA)),
                ]),
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _step1Name(),
    1 => _step2Photos(),
    2 => _step3City(),
    3 => _step4WorkType(),
    4 => _step5Shop(),
    5 => _step6Portfolio(),
    6 => _step7Bio(),
    7 => _step8Services(),
    8 => _step9Schedule(),
    _ => const SizedBox.shrink(),
  };

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 1 — Name
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step1Name() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("What's your name?", style: _kHeadline),
      const SizedBox(height: 8),
      const Text('This is how customers will see you in the app.',
          style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
      const SizedBox(height: 36),
      _lbl('FIRST NAME'), const SizedBox(height: 8),
      _field(ctrl: _firstCtrl, hint: 'Alex', cap: TextCapitalization.words),
      const SizedBox(height: 16),
      _lbl('LAST NAME'), const SizedBox(height: 8),
      _field(ctrl: _lastCtrl, hint: 'Rivera', cap: TextCapitalization.words),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 2 — Photos
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step2Photos() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Add your photos', style: _kHeadline),
      const SizedBox(height: 8),
      const Text('A profile photo and a cover image help customers recognize you and your space.',
          style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFFFCC02), width: 1),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB8860B)),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Her iki fotoğraf da zorunludur.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A5C00), height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 20),
      _lbl('COVER PHOTO *'), const SizedBox(height: 10),
      GestureDetector(
        onTap: () async {
          final f = await _pickFile();
          if (f != null) setState(() => _coverPhoto = f);
        },
        child: Container(
          width: double.infinity, height: 160,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          child: _coverPhoto != null
              ? ClipRRect(borderRadius: BorderRadius.circular(15),
                  child: Image.file(_coverPhoto!, fit: BoxFit.cover))
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add, size: 28, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 8),
                  Text('Tap to add cover photo',
                      style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))),
                ]),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Wide image, 16:9 works best',
          style: TextStyle(fontSize: 12, color: _kGreyL)),
      const SizedBox(height: 24),
      _lbl('PROFILE PHOTO *'), const SizedBox(height: 12),
      Row(children: [
        GestureDetector(
          onTap: () async {
            final f = await _pickFile();
            if (f != null) setState(() => _profilePhoto = f);
          },
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE), shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: _profilePhoto != null
                ? ClipOval(child: Image.file(_profilePhoto!, fit: BoxFit.cover))
                : const Icon(Icons.person_outline_rounded, size: 30, color: Color(0xFFAAAAAA)),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add a profile photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kBlack)),
            SizedBox(height: 4),
            Text('Square image. Customers see this on your profile and in chats.',
                style: TextStyle(fontSize: 12, color: _kGrey, height: 1.4)),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        _srcBtn(label: 'From camera', onTap: () async {
          final f = await _pickFile();
          if (f != null) setState(() => _profilePhoto = f);
        }),
        const SizedBox(width: 12),
        _srcBtn(label: 'From library', onTap: () async {
          final f = await _pickFile();
          if (f != null) setState(() => _profilePhoto = f);
        }),
      ]),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 3 — City (backend)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step3City() {
    final q = _citySearchCtrl.text.toLowerCase();
    final filtered = _cities
        .where((c) => (c['name'] ?? '').toLowerCase().contains(q))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hangi şehirde\nçalışıyorsun?', style: _kHeadline),
          const SizedBox(height: 8),
          const Text('Hizmetlerini yakındaki müşterilere göstereceğiz.',
              style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
          const SizedBox(height: 24),
          _lbl('ARA'), const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1.5),
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search_rounded, color: Color(0xFFBBBBBB), size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _citySearchCtrl,
                  style: const TextStyle(fontSize: 15, color: _kBlack),
                  decoration: const InputDecoration(
                    hintText: 'Şehir ara...',
                    hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),

      // ── Loading / Error / List ──────────────────────────────────────────────
      if (_citiesLoading)
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: _kBlue, strokeWidth: 2.5,
            ),
          ),
        )
      else if (_citiesError != null)
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFCCCCCC)),
              const SizedBox(height: 12),
              const Text('Şehirler yüklenemedi',
                  style: TextStyle(fontSize: 14, color: _kGrey)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchCities,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kBlue, borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('Tekrar dene',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        )
      else
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('Şehir bulunamadı',
                      style: TextStyle(fontSize: 14, color: _kGrey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final city = filtered[i];
                    final id   = city['id']!;
                    final name = city['name']!;
                    final sel  = _selectedCityId == id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedCityId   = id;
                        _selectedCityName = name;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: sel ? _kBlueBg : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel ? _kBlue.withOpacity(0.4) : _kBorder,
                            width: sel ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_on_outlined, size: 18,
                              color: sel ? _kBlue : const Color(0xFFAAAAAA)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(name, style: TextStyle(
                            fontSize: 15,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                            color: sel ? _kBlue : _kBlack,
                          ))),
                          if (sel)
                            const Icon(Icons.check_rounded,
                                size: 18, color: _kBlue),
                        ]),
                      ),
                    );
                  },
                ),
        ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 4 — Work type
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step4WorkType() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('What kind of\nwork do you do?', style: _kHeadline),
      const SizedBox(height: 8),
      const Text('Pick the category that fits best. You can offer multiple services later.',
          style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
      const SizedBox(height: 28),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05,
        ),
        itemCount: _venueOptions.length,
        itemBuilder: (_, i) {
          final opt = _venueOptions[i];
          final sel = _venueType == opt.type;
          return GestureDetector(
            onTap: () => setState(() => _venueType = opt.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: sel ? _kBlueBg : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel ? _kBlue.withOpacity(0.4) : _kBorder,
                  width: sel ? 1.5 : 1.0,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: sel ? _kBlue : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(opt.icon, size: 20, color: sel ? Colors.white : const Color(0xFF888888)),
                ),
                const Spacer(),
                Text(opt.label, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: sel ? _kBlue : _kBlack,
                )),
                const SizedBox(height: 4),
                Text(opt.sub, style: TextStyle(
                  fontSize: 12, height: 1.3,
                  color: sel ? _kBlue.withOpacity(0.7) : _kGrey,
                )),
              ]),
            ),
          );
        },
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 5 — Shop name
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step5Shop() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Name your shop', style: _kHeadline),
      const SizedBox(height: 8),
      const Text("If you work at a salon or shop, use its name. If you're solo, your own works great.",
          style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
      const SizedBox(height: 32),
      _lbl('SHOP / BUSINESS NAME'), const SizedBox(height: 8),
      _field(ctrl: _shopCtrl, hint: 'North Side Cuts', cap: TextCapitalization.sentences),
      const SizedBox(height: 16),
      _lbl('TAGLINE (OPTIONAL)'), const SizedBox(height: 8),
      _field(ctrl: _taglineCtrl, hint: 'Sharp fades. Honest prices.'),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("You can add services, prices and photos from your dashboard once you're in.",
                style: TextStyle(fontSize: 13, color: _kBlue, height: 1.5)),
          ),
        ]),
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 6 — Portfolio
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step6Portfolio() {
    final added = _portfolio.where((f) => f != null).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Show your work', style: _kHeadline),
        const SizedBox(height: 8),
        const Text('Add a few photos so customers can see your style. You can add more later.',
            style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
        const SizedBox(height: 28),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: 6,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () async {
              final f = await _pickFile();
              if (f != null) setState(() => _portfolio[i] = f);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              child: _portfolio[i] != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.file(_portfolio[i]!, fit: BoxFit.cover))
                  : const Center(child: Icon(Icons.add, size: 22, color: Color(0xFFCCCCCC))),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _srcBtn(label: 'From camera', onTap: () async {
            final idx = _portfolio.indexWhere((f) => f == null);
            if (idx == -1) return;
            final f = await _pickFile();
            if (f != null) setState(() => _portfolio[idx] = f);
          }),
          const SizedBox(width: 12),
          _srcBtn(label: 'From library', onTap: () async {
            final idx = _portfolio.indexWhere((f) => f == null);
            if (idx == -1) return;
            final f = await _pickFile();
            if (f != null) setState(() => _portfolio[idx] = f);
          }),
        ]),
        const SizedBox(height: 12),
        Text('$added of 6 added · square photos work best',
            style: const TextStyle(fontSize: 12, color: _kGreyL)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 7 — Bio
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step7Bio() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tell customers\nabout you', style: _kHeadline),
      const SizedBox(height: 8),
      const Text('A short intro builds trust. Mention your style, training, what you love about the craft.',
          style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
      const SizedBox(height: 32),
      _lbl('YEARS OF EXPERIENCE'), const SizedBox(height: 8),
      _field(ctrl: _yearsCtrl, hint: 'e.g. 5', type: TextInputType.number,
          fmt: [FilteringTextInputFormatter.digitsOnly]),
      const SizedBox(height: 16),
      _lbl('ABOUT YOU'), const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder, width: 1.5)),
        child: TextField(
          controller: _bioCtrl, maxLines: 5, maxLength: 240,
          style: const TextStyle(fontSize: 15, color: _kBlack, height: 1.5),
          decoration: const InputDecoration(
            hintText: "Hey, I'm Alex. I specialize in skin fades and beard line-ups. Trained at the Brooklyn Cut Co-op...",
            hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.all(16), counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Markdown isn't supported. Plain text only.",
            style: TextStyle(fontSize: 11, color: _kGreyL)),
        Text('${_bioCtrl.text.length}/240',
            style: const TextStyle(fontSize: 11, color: _kGreyL)),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✦', style: TextStyle(fontSize: 14, color: _kBlue)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tip: profiles with a real photo and 3+ sentences of bio get 2.4× more bookings in the first month.',
              style: TextStyle(fontSize: 13, color: _kBlue, height: 1.5),
            ),
          ),
        ]),
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 8 — Services
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step8Services() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('What do you offer?', style: _kHeadline),
          const SizedBox(height: 8),
          const Text('Set your services and prices. You can edit these any time from your profile.',
              style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
          const SizedBox(height: 12),
          const Text('Her hizmet için isim, fiyat ve süre zorunludur.',
              style: TextStyle(fontSize: 13, color: Color(0xFFB8860B), height: 1.4)),
          const SizedBox(height: 16),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          children: [
            ..._services.asMap().entries.map((e) => _ServiceCard(
              service: e.value,
              onRemove: () => setState(() => _services.removeAt(e.key)),
              onChanged: () => setState(() {}),
            )),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _services.add(_Service(name: '', price: '', duration: ''))),
              child: const Row(children: [
                Icon(Icons.add, size: 18, color: _kBlack),
                SizedBox(width: 6),
                Text('Add service',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kBlack)),
              ]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 9 — Schedule
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _step9Schedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('When do you work?', style: _kHeadline),
          SizedBox(height: 8),
          Text('Set the hours customers can book you. You can block off specific days or hours later.',
              style: TextStyle(fontSize: 15, color: _kGrey, height: 1.5)),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _schedule.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final d = _schedule[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Switch(
                    value: d.enabled,
                    onChanged: (v) => setState(() => d.enabled = v),
                    activeColor: _kBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(width: 36,
                    child: Text(d.day, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: d.enabled ? _kBlack : _kGreyL,
                    )),
                  ),
                  const SizedBox(width: 10),
                  if (d.enabled) ...[
                    _timePill(d.start, () async {
                      final t = await showTimePicker(context: context, initialTime: d.start);
                      if (t != null) setState(() => d.start = t);
                    }),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—', style: TextStyle(color: _kGreyL)),
                    ),
                    _timePill(d.end, () async {
                      final t = await showTimePicker(context: context, initialTime: d.end);
                      if (t != null) setState(() => d.end = t);
                    }),
                  ] else
                    const Text('Closed', style: TextStyle(fontSize: 14, color: _kGreyL)),
                ]),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _timePill(TimeOfDay t, VoidCallback onTap) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$h:$m',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kBlack)),
          const SizedBox(width: 4),
          const Icon(Icons.access_time_rounded, size: 13, color: _kGreyL),
        ]),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────
  Widget _lbl(String t) => Text(t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.8));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    TextInputType type = TextInputType.text,
    TextCapitalization cap = TextCapitalization.none,
    List<TextInputFormatter>? fmt,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder, width: 1.5)),
      child: TextField(
        controller: ctrl, keyboardType: type,
        textCapitalization: cap, inputFormatters: fmt,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _kBlack),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
          border: InputBorder.none, enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _srcBtn({required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.photo_library_outlined, size: 16, color: _kBlack),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kBlack)),
          ]),
        ),
      );
}

// ── Service Card ──────────────────────────────────────────────────────────────
class _ServiceCard extends StatefulWidget {
  final _Service service;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ServiceCard({required this.service, required this.onRemove, required this.onChanged});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  late final TextEditingController _name, _price, _dur;

  @override
  void initState() {
    super.initState();
    _name  = TextEditingController(text: widget.service.name);
    _price = TextEditingController(text: widget.service.price);
    _dur   = TextEditingController(text: widget.service.duration);
  }

  @override
  void dispose() { _name.dispose(); _price.dispose(); _dur.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kBlack),
              decoration: const InputDecoration(
                hintText: 'Service name',
                hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) { widget.service.name = v; widget.onChanged(); },
            ),
          ),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFBBBBBB)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _miniField(ctrl: _price, prefix: '\$', suffix: null,
              onChanged: (v) { widget.service.price = v; widget.onChanged(); }),
          const SizedBox(width: 10),
          _miniField(ctrl: _dur, prefix: null, suffix: 'min',
              onChanged: (v) { widget.service.duration = v; widget.onChanged(); }),
        ]),
      ]),
    );
  }

  Widget _miniField({
    required TextEditingController ctrl,
    required String? prefix,
    required String? suffix,
    required void Function(String) onChanged,
  }) {
    return Container(
      width: prefix != null ? 80 : 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6), borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        if (prefix != null) ...[
          Text(prefix, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kGrey)),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kBlack),
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
        if (suffix != null)
          Text(' $suffix', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kGrey)),
      ]),
    );
  }
}
