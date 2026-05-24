import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/barber_auth_service.dart';
import '../services/auth_storage.dart';
import 'barber_home_screen.dart';
import 'barber_register_screen.dart';

class BarberLoginScreen extends StatefulWidget {
  const BarberLoginScreen({super.key});

  @override
  State<BarberLoginScreen> createState() => _BarberLoginScreenState();
}

class _BarberLoginScreenState extends State<BarberLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrls  = List.generate(4, (_) => TextEditingController());
  final _otpNodes  = List.generate(4, (_) => FocusNode());

  bool _showOtp = false;
  bool _loading = false;

  static const _bg     = Color(0xFFF4F4F4);
  static const _black  = Color(0xFF1A1A1A);
  static const _grey   = Color(0xFF888888);
  static const _border = Color(0xFFE8E8E8);
  static const _blue   = Color(0xFF3875F6);

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _prefill() async {
    final saved = await AuthStorage.getPhone();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _phoneCtrl.text = saved.replaceAll(RegExp(r'^\+\d+'), ''));
    }
  }

  String get _fullPhone => '+993${_phoneCtrl.text}';

  bool get _phoneValid => _phoneCtrl.text.length == 8;

  // ── OTP gönder ────────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_phoneValid) return;
    setState(() => _loading = true);
    try {
      await BarberAuthService.requestOtp(_fullPhone);
      if (!mounted) return;
      setState(() { _loading = false; _showOtp = true; });
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      _otpNodes[0].requestFocus();
      _snack('Dev mod: kod 1234');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString(), red: true);
    }
  }

  // ── OTP doğrula ───────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length < 4) return;
    setState(() => _loading = true);
    try {
      await BarberAuthService.verifyOtp(_fullPhone, code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BarberHomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString(), red: true);
    }
  }

  void _onOtpKey(String val, int i) {
    if (val.length == 1 && i < 3) _otpNodes[i + 1].requestFocus();
    if (val.isEmpty  && i > 0)   _otpNodes[i - 1].requestFocus();
    if (_otpCtrls.map((c) => c.text).join().length == 4) _verifyOtp();
  }

  void _snack(String msg, {bool red = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: red ? Colors.redAccent : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _backButton(context),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showOtp ? _otpHeader() : _phoneHeader(),
              ),
              const SizedBox(height: 36),
              if (!_showOtp) ...[
                _fieldLabel('TELEFON NUMARASI'),
                const SizedBox(height: 8),
                _phoneField(),
              ] else ...[
                _fieldLabel('DOĞRULAMA KODU'),
                const SizedBox(height: 12),
                _otpRow(),
                const SizedBox(height: 16),
                _resendRow(),
              ],
              const SizedBox(height: 28),
              _actionButton(),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const BarberRegisterScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: _grey),
                      children: [
                        TextSpan(text: 'Hesabın yok mu? '),
                        TextSpan(
                          text: 'Kayıt ol',
                          style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _phoneHeader() => Column(
    key: const ValueKey('phone'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      Text('Hoş geldiniz',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
              color: _black, letterSpacing: -0.6)),
      SizedBox(height: 6),
      Text('Devam etmek için telefon numaranı gir.',
          style: TextStyle(fontSize: 15, color: _grey, height: 1.4)),
    ],
  );

  Widget _otpHeader() => Column(
    key: const ValueKey('otp'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Kodu gir',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
              color: _black, letterSpacing: -0.6)),
      const SizedBox(height: 6),
      RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: _grey, height: 1.4),
          children: [
            const TextSpan(text: '+993 '),
            TextSpan(
              text: _phoneCtrl.text,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _black),
            ),
            const TextSpan(text: ' numarasına gönderildi.'),
          ],
        ),
      ),
    ],
  );

  // ── Phone field ───────────────────────────────────────────────────────────────
  Widget _phoneField() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border, width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
          ),
          child: const Text('🇹🇲 +993',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black)),
        ),
        Expanded(
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _black),
            decoration: const InputDecoration(
              hintText: 'XX XX XX XX',
              hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) { if (_phoneValid) _sendOtp(); },
          ),
        ),
      ],
    ),
  );

  // ── OTP row ───────────────────────────────────────────────────────────────────
  Widget _otpRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: List.generate(4, (i) => SizedBox(
      width: 68, height: 68,
      child: TextField(
        controller: _otpCtrls[i],
        focusNode:  _otpNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _black),
        decoration: InputDecoration(
          counterText: '',
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blue, width: 2.0),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => _onOtpKey(v, i),
      ),
    )),
  );

  Widget _resendRow() => Row(
    children: [
      const Text('Kod gelmedi mi? ',
          style: TextStyle(fontSize: 13, color: _grey)),
      GestureDetector(
        onTap: _sendOtp,
        child: const Text('Tekrar gönder',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
      ),
    ],
  );

  // ── Action button ─────────────────────────────────────────────────────────────
  Widget _actionButton() {
    final enabled = _showOtp
        ? _otpCtrls.every((c) => c.text.isNotEmpty)
        : _phoneValid;
    final label = _showOtp ? 'Doğrula' : 'Kod gönder';

    return GestureDetector(
      onTap: enabled && !_loading ? (_showOtp ? _verifyOtp : _sendOtp) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          color: enabled ? _blue : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1,
                    color: enabled ? Colors.white : const Color(0xFFAAAAAA),
                  )),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: const Icon(Icons.chevron_left, color: _black, size: 24),
    ),
  );

  Widget _fieldLabel(String t) => Text(t,
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.8,
      ));
}
