import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'barber_onboarding_screen.dart';

class BarberRegisterScreen extends StatefulWidget {
  const BarberRegisterScreen({super.key});

  @override
  State<BarberRegisterScreen> createState() => _BarberRegisterScreenState();
}

class _BarberRegisterScreenState extends State<BarberRegisterScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  static const _bg     = Color(0xFFF4F4F4);
  static const _black  = Color(0xFF1A1A1A);
  static const _grey   = Color(0xFF888888);
  static const _border = Color(0xFFE8E8E8);
  static const _blue   = Color(0xFF3875F6);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue => _phoneCtrl.text.length == 8;

  void _continue() {
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarberOnboardingScreen(
            email: '',
            phone: _phoneCtrl.text.trim(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _backButton(context),
              const SizedBox(height: 32),
              const Text(
                'Create your\naccount',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _black,
                  height: 1.2,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Takes about a minute. We'll set up your profile next.",
                style: TextStyle(fontSize: 15, color: _grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              _fieldLabel('PHONE NUMBER'),
              const SizedBox(height: 8),
              _phoneField(),
              const SizedBox(height: 32),
              _continueButton(),
              const Spacer(),
              const Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA), height: 1.55),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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

  Widget _fieldLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: _grey, letterSpacing: 0.8,
    ),
  );

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
          child: const Text(
            '🇹🇲 +993',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black),
          ),
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
            onSubmitted: (_) { if (_canContinue) _continue(); },
          ),
        ),
      ],
    ),
  );

  Widget _continueButton() => GestureDetector(
    onTap: _canContinue && !_loading ? _continue : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        color: _canContinue ? _blue : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Center(
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1,
                  color: _canContinue ? Colors.white : const Color(0xFFAAAAAA),
                ),
              ),
      ),
    ),
  );
}
