import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/barber_landing_screen.dart';
import 'screens/barber_register_screen.dart';
import 'screens/barber_login_screen.dart';
import 'screens/barber_home_screen.dart';
import 'screens/waiting_approval_screen.dart';
import 'services/auth_storage.dart';
import 'utils/app_theme.dart';
import 'utils/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initTheme();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const BarberApp());
}

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Dellekci — Berber',
        debugShowCheckedModeBanner: false,
        theme:      AppTheme.lightTheme,
        darkTheme:  AppTheme.darkTheme,
        themeMode:  mode,
        home: const BarberSplashScreen(),
        routes: {
          '/landing':  (_) => const BarberLandingScreen(),
          '/register': (_) => const BarberRegisterScreen(),
          '/login':    (_) => const BarberLoginScreen(),
          '/waiting':  (_) => const WaitingApprovalScreen(),
          '/home':     (_) => const BarberHomeScreen(),
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Splash Screen
// ═══════════════════════════════════════════════════════════════════════════════
class BarberSplashScreen extends StatefulWidget {
  const BarberSplashScreen({super.key});

  @override
  State<BarberSplashScreen> createState() => _BarberSplashScreenState();
}

class _BarberSplashScreenState extends State<BarberSplashScreen>
    with TickerProviderStateMixin {
  // Dış halka genişlemesi
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ringScale;
  late final Animation<double>   _ringFade;

  // Makas ikonu
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _logoRotate;
  late final Animation<double>   _logoFade;

  // Metin
  late final AnimationController _textCtrl;
  late final Animation<double>   _textFade;
  late final Animation<Offset>   _textSlide;

  // Çizgi
  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineWidth;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _ringScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
    _ringFade = Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoRotate = Tween<double>(begin: -pi / 4, end: 0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));

    _lineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOut));

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _ringCtrl.forward();
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    _lineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _textCtrl.forward();

    // Auth kontrolü & minimum splash süresi
    final results = await Future.wait([
      _resolveRoute(),
      Future.delayed(const Duration(milliseconds: 3400)),
    ]);

    // Çıkış
    await Future.wait([_textCtrl.reverse(), _logoCtrl.reverse()]);
    if (!mounted) return;

    final screen = results[0] as Widget;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<Widget> _resolveRoute() async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    if (isLoggedIn) return const BarberHomeScreen();
    final status = await AuthStorage.getStatus();
    if (status == 'pending')  return const WaitingApprovalScreen();
    if (status == 'approved') return const BarberLoginScreen();
    return const BarberLandingScreen();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _logoCtrl.dispose();
    _lineCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1E),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif arka plan noktaları
            _buildDots(),
            // İçerik
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildText(),
                ],
              ),
            ),
            // Alt versiyon etiketi
            _buildBottomTag(),
          ],
        ),
      ),
    );
  }

  // ── Arka plan dekoratif daireler ────────────────────────────────────────────
  Widget _buildDots() {
    return Stack(children: [
      Positioned(
        top: -60, right: -60,
        child: AnimatedBuilder(
          animation: _ringCtrl,
          builder: (_, __) => Opacity(
            opacity: (_ringFade.value * 0.3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _ringScale.value * 1.4,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      width: 1),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -80, left: -80,
        child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent.withValues(alpha: 0.03),
          ),
        ),
      ),
      Positioned(
        top: 100, left: -40,
        child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.02),
          ),
        ),
      ),
    ]);
  }

  // ── Makas logosu ────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoCtrl,
      builder: (_, __) => Opacity(
        opacity: _logoFade.value,
        child: Transform.scale(
          scale: _logoScale.value,
          child: Transform.rotate(
            angle: _logoRotate.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dış parıltı halkası
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.25),
                        AppTheme.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Ana daire
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFB347), Color(0xFFE8A045)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.50),
                        blurRadius: 36,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('✂️', style: TextStyle(fontSize: 50)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Altın çizgi ─────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return AnimatedBuilder(
      animation: _lineCtrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180 * _lineWidth.value,
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                AppTheme.accent.withValues(alpha: 0.7),
                AppTheme.accent,
                AppTheme.accent.withValues(alpha: 0.7),
                Colors.transparent,
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metin ───────────────────────────────────────────────────────────────────
  Widget _buildText() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            const Text(
              'Dellekci',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BERBER PANELİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Alt etiket ──────────────────────────────────────────────────────────────
  Widget _buildBottomTag() {
    return Positioned(
      bottom: 48,
      left: 0, right: 0,
      child: FadeTransition(
        opacity: _textFade,
        child: Center(
          child: Text(
            'Profesyonel Randevu Yönetimi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.30),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
