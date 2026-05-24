import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/barber_profile_service.dart';
import '../utils/app_theme.dart';

class BarberProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;
  final bool isOnboarding;
  final VoidCallback? onOnboardingComplete;
  final VoidCallback? onLogout;
  final int initialTab;
  const BarberProfileEditScreen({
    super.key,
    this.existingProfile,
    this.isOnboarding = false,
    this.onOnboardingComplete,
    this.onLogout,
    this.initialTab = 0,
  });

  @override
  State<BarberProfileEditScreen> createState() =>
      _BarberProfileEditScreenState();
}

class _BarberProfileEditScreenState extends State<BarberProfileEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _salonName = '';
  final _addressCtrl = TextEditingController();
  final _aboutCtrl   = TextEditingController();
  String _coverImage  = '';
  String _avatarImage = '';

  List<Map<String, String>> _cities      = [];
  String?                   _selectedCityId;
  bool                      _citiesError = false;

  final List<Map<String, dynamic>> _services  = [];
  final List<String>               _portfolio = [];

  final List<Map<String, dynamic>> _hours = [
    {'day': 'monday',    'label': 'Pazartesi', 'open': '09:00', 'close': '20:00', 'closed': false},
    {'day': 'tuesday',   'label': 'Salı',      'open': '09:00', 'close': '20:00', 'closed': false},
    {'day': 'wednesday', 'label': 'Çarşamba',  'open': '09:00', 'close': '20:00', 'closed': false},
    {'day': 'thursday',  'label': 'Perşembe',  'open': '09:00', 'close': '20:00', 'closed': false},
    {'day': 'friday',    'label': 'Cuma',      'open': '09:00', 'close': '21:00', 'closed': false},
    {'day': 'saturday',  'label': 'Cumartesi', 'open': '10:00', 'close': '19:00', 'closed': false},
    {'day': 'sunday',    'label': 'Pazar',     'open': '10:00', 'close': '18:00', 'closed': true},
  ];

  bool    _isLoading     = true;
  bool    _loadError     = false;
  bool    _isSaving      = false;
  String? _uploadingField;

  static const _serviceIcons = [
    '✂️','🪒','💈','🧴','🎨','⭐','🧖','⚡','🌊','👶',
    '💅','💆','🚿','🚗','✨','🛁',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addressCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() { _isLoading = true; _loadError = false; });

    // Cities
    try {
      final cities = await BarberProfileService.getCities();
      if (mounted) setState(() { _cities = cities; _citiesError = false; });
    } catch (_) {
      if (mounted) setState(() => _citiesError = true);
    }

    // Profile
    try {
      Map<String, dynamic>? profile = widget.existingProfile;
      profile ??= await BarberProfileService.getProfile();

      if (profile != null && profile['profileComplete'] == true) {
        _salonName          = (profile['name']        as String?) ?? '';
        _addressCtrl.text   = (profile['address']     as String?) ?? '';
        _aboutCtrl.text     = (profile['about']       as String?) ?? '';
        _coverImage         = (profile['coverImage']  as String?) ?? '';
        _avatarImage        = (profile['avatarImage'] as String?) ?? '';

        final city = profile['city'] as Map?;
        _selectedCityId = city?['id'] as String?;

        final svcs = (profile['services'] as List?) ?? [];
        _services
          ..clear()
          ..addAll(svcs.map<Map<String, dynamic>>((s) => {
                'name':        (s['name'] ?? '')      as Object,
                'price':       ((s['price'] as num?)?.toDouble() ?? 0.0) as Object,
                'durationMin': ((s['durationMin'] as num?)?.toInt() ?? 30) as Object,
                'icon':        (s['icon'] ?? '✂️')   as Object,
              }));

        final port = (profile['portfolio'] as List?) ?? [];
        _portfolio
          ..clear()
          ..addAll(port.map<String>((p) => (p as Map)['imageUrl'] as String? ?? ''));

        final wh = (profile['workingHours'] as List?) ?? [];
        for (final h in _hours) {
          final match = wh.cast<Map?>().firstWhere(
            (x) => x?['day'] == h['day'],
            orElse: () => null,
          );
          if (match != null) {
            h['closed'] = (match['isClosed'] as bool?) ?? false;
            h['open']   = match['openTime']  ?? '09:00';
            h['close']  = match['closeTime'] ?? '20:00';
          }
        }
      } else if (profile != null) {
        _salonName      = (profile['salonName']   as String?) ?? '';
        _aboutCtrl.text = (profile['about']        as String?) ?? '';
        _coverImage     = (profile['coverImage']   as String?) ?? '';
        _avatarImage    = (profile['avatarImage']  as String?) ?? '';

        final regCityId = profile['cityId'] as String?;
        if (regCityId != null) _selectedCityId = regCityId;

        // Services: [{name, price, duration}]
        const dayMap = {
          'Mon': 'monday',  'Tue': 'tuesday', 'Wed': 'wednesday',
          'Thu': 'thursday','Fri': 'friday',  'Sat': 'saturday', 'Sun': 'sunday',
        };
        final regServices = (profile['registrationServices'] as List?) ?? [];
        if (regServices.isNotEmpty) {
          _services.clear();
          _services.addAll(regServices.map<Map<String, dynamic>>((s) => {
            'name':        ((s as Map)['name'] ?? '') as Object,
            'price':       (double.tryParse(s['price']?.toString() ?? '0') ?? 0.0) as Object,
            'durationMin': (int.tryParse(s['duration']?.toString() ?? '30') ?? 30) as Object,
            'icon':        '✂️' as Object,
          }));
        }

        // Working hours: [{day: 'Mon', enabled: bool, start: 'HH:MM', end: 'HH:MM'}]
        final regHours = (profile['registrationWorkingHours'] as List?) ?? [];
        for (final h in _hours) {
          final match = regHours.cast<Map?>().firstWhere(
            (x) => dayMap[x?['day']] == h['day'],
            orElse: () => null,
          );
          if (match != null) {
            h['closed'] = !(match['enabled'] as bool? ?? true);
            h['open']   = match['start'] ?? '09:00';
            h['close']  = match['end']   ?? '18:00';
          }
        }

        // Portfolio
        final regPortfolio = (profile['portfolioUrls'] as List?) ?? [];
        if (regPortfolio.isNotEmpty) {
          _portfolio.clear();
          _portfolio.addAll(regPortfolio.cast<String>());
        }
      }

      if (_selectedCityId == null && _cities.isNotEmpty) {
        _selectedCityId = _cities.first['id'];
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Image Upload ────────────────────────────────────────────────────────────
  Future<void> _pickImage(String field) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _uploadingField = field);
    try {
      final url = await BarberProfileService.uploadImageBytes(
          bytes: file.bytes!, filename: file.name);
      if (!mounted) return;
      setState(() {
        if (field == 'cover')  _coverImage  = url;
        if (field == 'avatar') _avatarImage = url;
      });
    } catch (e) {
      if (mounted) _showError('Yükleme hatası: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  Future<void> _pickPortfolioImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: true, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploadingField = 'portfolio');
    try {
      for (final file in result.files) {
        if (file.bytes == null) continue;
        final url = await BarberProfileService.uploadImageBytes(
            bytes: file.bytes!, filename: file.name);
        if (mounted) setState(() => _portfolio.add(url));
      }
    } catch (e) {
      if (mounted) _showError('Yükleme hatası: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  // ── Tamamlanma kontrolleri ──────────────────────────────────────────────────
  bool get _generalComplete =>
      _selectedCityId != null &&
      _addressCtrl.text.trim().isNotEmpty &&
      _coverImage.isNotEmpty &&
      _avatarImage.isNotEmpty;

  bool get _servicesComplete =>
      _services.any((s) => (s['name'] as String).trim().isNotEmpty);

  bool get _hoursComplete =>
      _hours.any((h) => !(h['closed'] as bool));

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    // Tab 1 — Genel
    if (_selectedCityId == null) {
      _tabController.animateTo(0);
      _showError('Lütfen şehir seçin.');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      _tabController.animateTo(0);
      _showError('Adres alanı zorunludur.');
      return;
    }
    if (_coverImage.isEmpty) {
      _tabController.animateTo(0);
      _showError('Kapak fotoğrafı zorunludur.');
      return;
    }
    if (_avatarImage.isEmpty) {
      _tabController.animateTo(0);
      _showError('Profil fotoğrafı zorunludur.');
      return;
    }

    // Tab 2 — Hizmetler
    final validServices = _services
        .where((s) => (s['name'] as String).trim().isNotEmpty)
        .toList();
    if (validServices.isEmpty) {
      _tabController.animateTo(1);
      _showError('En az 1 hizmet eklemeniz gereklidir.');
      return;
    }

    // Tab 3 — Saatler
    final hasOpenDay = _hours.any((h) => !(h['closed'] as bool));
    if (!hasOpenDay) {
      _tabController.animateTo(2);
      _showError('En az 1 açık gün belirtmelisiniz.');
      return;
    }

    final nameToSend = _salonName.trim().isNotEmpty
        ? _salonName.trim()
        : _addressCtrl.text.trim();

    setState(() => _isSaving = true);
    try {
      await BarberProfileService.saveProfile(
        name:         nameToSend,
        cityId:       _selectedCityId!,
        address:      _addressCtrl.text.trim(),
        about:        _aboutCtrl.text.trim(),
        coverImage:   _coverImage,
        avatarImage:  _avatarImage,
        services:     validServices,
        portfolioUrls: _portfolio,
        workingHours: _hours.map((h) => {
              'day':       h['day'],
              'openTime':  h['closed'] as bool ? null : h['open'],
              'closeTime': h['closed'] as bool ? null : h['close'],
              'isClosed':  h['closed'],
            }).toList(),
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Profil kaydedildi!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      if (widget.isOnboarding) {
        widget.onOnboardingComplete?.call();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
          widget.isOnboarding
              ? 'Profilinizi Tamamlayın'
              : (_salonName.isNotEmpty ? _salonName : 'Profilimi Düzenle'),
        ),
        actions: [
          if (widget.onLogout != null && !widget.isOnboarding)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Çıkış Yap',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Çıkış Yap',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Çıkış Yap',
                            style: TextStyle(color: Colors.redAccent,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (ok == true) widget.onLogout?.call();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppTheme.primary))
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      widget.isOnboarding ? 'Tamamla' : 'Kaydet',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                          fontSize: 15),
                    )),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Genel'),
              const SizedBox(width: 5),
              _TabStatus(ok: _generalComplete),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Hizmetler'),
              const SizedBox(width: 5),
              _TabStatus(ok: _servicesComplete),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Saatler'),
              const SizedBox(width: 5),
              _TabStatus(ok: _hoursComplete),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Portfolyo'),
              if (_portfolio.isNotEmpty) ...[
                const SizedBox(width: 5),
                _TabBadge(_portfolio.length),
              ],
            ])),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2.5))
          : _loadError && _salonName.isEmpty && _addressCtrl.text.isEmpty
          ? _buildRetryView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildServicesTab(),
                _buildHoursTab(),
                _buildPortfolioTab(),
              ],
            ),
    );
  }

  Widget _buildRetryView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          const Text('Profil yüklenemedi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Bağlantını kontrol edip tekrar dene',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
            onPressed: _loadData,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Tab 1: Genel ─────────────────────────────────────────────────────────────
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.isOnboarding) ...[
          _RequiredBanner(items: const [
            'Kapak ve profil fotoğrafı',
            'Şehir ve adres',
          ]),
          const SizedBox(height: 16),
        ],
        _buildImagePicker(label: 'Kapak Fotoğrafı *', imageUrl: _coverImage,
            field: 'cover', height: 180, icon: Icons.panorama_rounded),
        const SizedBox(height: 16),
        _buildImagePicker(label: 'Profil Fotoğrafı *', imageUrl: _avatarImage,
            field: 'avatar', height: 120, icon: Icons.person_rounded),
        const SizedBox(height: 24),
        _buildCityPicker(),
        const SizedBox(height: 16),
        _buildField('Adres *', _addressCtrl, 'Mahalle, İlçe'),
        const SizedBox(height: 16),
        _buildField('Hakkında', _aboutCtrl,
            'Salonunuz hakkında kısa bir açıklama…', maxLines: 4),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String imageUrl,
    required String field,
    required double height,
    required IconData icon,
  }) {
    final isUploading = _uploadingField == field;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: isUploading ? null : () => _pickImage(field),
        child: Container(
          width: double.infinity, height: height,
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider, width: 1.5),
            image: imageUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: isUploading
              ? const Center(child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppTheme.primary))
              : imageUrl.isEmpty
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 36, color: AppTheme.textTertiary),
                  const SizedBox(height: 8),
                  const Text('Fotoğraf seç', style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 13,
                      fontWeight: FontWeight.w500)),
                ])
              : Align(alignment: Alignment.bottomRight,
                  child: Padding(padding: const EdgeInsets.all(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.8),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded,
                          size: 14, color: Colors.white),
                    ))),
        ),
      ),
    ]);
  }

  // ── Tab 2: Hizmetler ──────────────────────────────────────────────────────────
  Widget _buildServicesTab() {
    return Column(children: [
      if (widget.isOnboarding && !_servicesComplete)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _RequiredBanner(items: const ['En az 1 hizmet eklenmeli']),
        ),
      Expanded(
        child: _services.isEmpty
            ? const _EmptyState(icon: '✂️', text: 'Henüz hizmet eklenmedi')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                itemCount: _services.length,
                itemBuilder: (_, i) => _buildServiceCard(i),
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Hizmet Ekle'),
            onPressed: () => setState(() => _services.add(
                  {'name': '', 'price': 0.0, 'durationMin': 30, 'icon': '✂️'})),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildServiceCard(int i) {
    final s = _services[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider, width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => _showIconPicker(i),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(s['icon'] as String,
                  style: const TextStyle(fontSize: 22))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: s['name'] as String,
              onChanged: (v) => _services[i]['name'] = v,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              decoration: _inlineDeco('Hizmet adı'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _services.removeAt(i)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _numericFormField(
            label: 'Fiyat (₺)',
            initial: (s['price'] as double).toStringAsFixed(0),
            onChanged: (v) => _services[i]['price'] = double.tryParse(v) ?? 0,
          )),
          const SizedBox(width: 10),
          Expanded(child: _numericFormField(
            label: 'Süre (dk)',
            initial: (s['durationMin'] as int).toString(),
            onChanged: (v) => _services[i]['durationMin'] = int.tryParse(v) ?? 30,
          )),
        ]),
      ]),
    );
  }

  void _showIconPicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('İkon Seç', style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: _serviceIcons.map((ic) => GestureDetector(
              onTap: () { setState(() => _services[index]['icon'] = ic); Navigator.pop(context); },
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _services[index]['icon'] == ic
                      ? AppTheme.accentLight : AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _services[index]['icon'] == ic
                          ? AppTheme.accent : AppTheme.divider),
                ),
                child: Center(child: Text(ic, style: const TextStyle(fontSize: 24))),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  // ── Tab 3: Saatler ──────────────────────────────────────────────────────────
  Widget _buildHoursTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hours.length,
      itemBuilder: (_, i) {
        final h        = _hours[i];
        final isClosed = h['closed'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isClosed ? AppTheme.background : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isClosed ? AppTheme.divider : AppTheme.primary.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Row(children: [
            SizedBox(width: 88,
              child: Text(h['label'] as String,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isClosed ? AppTheme.textTertiary : AppTheme.textPrimary)),
            ),
            GestureDetector(
              onTap: () => setState(() => _hours[i]['closed'] = !isClosed),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 24,
                decoration: BoxDecoration(
                    color: isClosed ? AppTheme.divider : AppTheme.success,
                    borderRadius: BorderRadius.circular(12)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isClosed ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: 18, height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (isClosed)
              const Text('Kapalı', style: TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary, fontWeight: FontWeight.w500))
            else ...[
              Expanded(child: _timeBtn(
                value: h['open'] as String,
                onChanged: (v) => setState(() => _hours[i]['open'] = v),
              )),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: AppTheme.textTertiary))),
              Expanded(child: _timeBtn(
                value: h['close'] as String,
                onChanged: (v) => setState(() => _hours[i]['close'] = v),
              )),
            ],
          ]),
        );
      },
    );
  }

  // ── Tab 4: Portfolyo ─────────────────────────────────────────────────────────
  Widget _buildPortfolioTab() {
    final isUploading = _uploadingField == 'portfolio';
    return Column(children: [
      Expanded(
        child: _portfolio.isEmpty
            ? const _EmptyState(icon: '🖼️', text: 'Henüz fotoğraf eklenmedi')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _portfolio.length,
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_portfolio[i],
                        width: double.infinity, height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.divider,
                            child: const Icon(Icons.broken_image_rounded,
                                color: AppTheme.textTertiary))),
                  ),
                  Positioned(top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _portfolio.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            icon: isUploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.5,
                        color: AppTheme.primary))
                : const Icon(Icons.add_photo_alternate_rounded),
            label: Text(isUploading ? 'Yükleniyor…' : 'Fotoğraf Ekle'),
            onPressed: isUploading ? null : _pickPortfolioImages,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── City picker ──────────────────────────────────────────────────────────────
  Widget _buildCityPicker() {
    final selectedName = _cities.firstWhere(
      (c) => c['id'] == _selectedCityId,
      orElse: () => {'name': _citiesError ? 'Yüklenemedi ⚠️' : 'Şehir seç'},
    )['name']!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Şehir *'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _cities.isEmpty
            ? () { if (_citiesError) _loadData(); }
            : _showCityDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _citiesError && _selectedCityId == null
                  ? Colors.redAccent.withOpacity(0.5)
                  : AppTheme.divider,
              width: 1.5,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(children: [
            Expanded(child: Text(selectedName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: _selectedCityId != null
                        ? AppTheme.textPrimary : AppTheme.textTertiary))),
            if (_citiesError && _cities.isEmpty)
              const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.accent)
            else
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppTheme.textSecondary),
          ]),
        ),
      ),
      if (_citiesError && _cities.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: _loadData,
            child: const Text('Şehirler yüklenemedi, dokunun →',
                style: TextStyle(fontSize: 11, color: Colors.redAccent,
                    fontWeight: FontWeight.w500)),
          ),
        ),
    ]);
  }

  Future<void> _showCityDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Şehir Seç', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 17)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cities.length,
            itemBuilder: (_, i) {
              final city       = _cities[i];
              final isSelected = city['id'] == _selectedCityId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                title: Text(city['name']!,
                    style: TextStyle(fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)),
                trailing: isSelected
                    ? Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: AppTheme.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white))
                    : null,
                onTap: () => Navigator.pop(ctx, city['id']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal',
                  style: TextStyle(color: AppTheme.textSecondary))),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _selectedCityId = picked);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _buildField(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider, width: 1.5),
          boxShadow: AppTheme.cardShadow,
        ),
        child: TextField(
          controller: ctrl, maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w400),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  InputDecoration _inlineDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 14,
        fontWeight: FontWeight.w400),
    filled: true, fillColor: AppTheme.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _numericFormField({
    required String label, required String initial,
    required void Function(String) onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextFormField(
        initialValue: initial,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary),
        decoration: _inlineDeco(''),
      ),
    ]);
  }

  Widget _timeBtn({required String value, required void Function(String) onChanged}) {
    final parts = value.split(':');
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null && mounted) {
          onChanged('${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(value, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary, letterSpacing: 0.3));
}

class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge(this.count);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: AppTheme.accent,
          borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(fontSize: 10,
          fontWeight: FontWeight.w800, color: Colors.white)));
}

class _TabStatus extends StatelessWidget {
  final bool ok;
  const _TabStatus({required this.ok});
  @override
  Widget build(BuildContext context) => Icon(
        ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        size: 14,
        color: ok ? AppTheme.success : AppTheme.textTertiary,
      );
}

class _RequiredBanner extends StatelessWidget {
  final List<String> items;
  const _RequiredBanner({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF856404)),
            SizedBox(width: 6),
            Text('Bu bölüm zorunludur',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF856404))),
          ]),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const SizedBox(width: 21),
                  const Text('• ', style: TextStyle(color: Color(0xFF856404))),
                  Text(item, style: const TextStyle(
                      fontSize: 11, color: Color(0xFF856404))),
                ]),
              )),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600)),
      ]));
}
