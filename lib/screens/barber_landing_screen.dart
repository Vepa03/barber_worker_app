import 'package:flutter/material.dart';
import 'barber_login_screen.dart';
import 'barber_register_screen.dart';

class BarberLandingScreen extends StatelessWidget {
  const BarberLandingScreen({super.key});

  static const _bg     = Color(0xFFF4F4F4);
  static const _black  = Color(0xFF1A1A1A);
  static const _grey   = Color(0xFF888888);
  static const _greyL  = Color(0xFFAAAAAA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildLogo(),
              const Spacer(),
              _buildBadge(),
              const SizedBox(height: 22),
              const Text(
                'Run your\nchair, your\nway.',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: _black,
                  height: 1.08,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Bookings, reviews, payouts and your week — all in one place. Built for barbers, stylists, therapists and detailers.',
                style: TextStyle(
                  fontSize: 15,
                  color: _grey,
                  height: 1.65,
                ),
              ),
              const Spacer(),
              _buildPrimaryButton(
                label: 'Create your worker account',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BarberRegisterScreen()),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BarberLoginScreen()),
                  ),
                  child: const Text(
                    'I already have an account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _greyL, height: 1.55),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.content_cut_rounded, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Nobat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'For service workers',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF4060CC),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
