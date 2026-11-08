import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF1F5F9), Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            // Lingkaran Ambient Kanan Atas
            Positioned(
              top: -70,
              right: -70,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Lingkaran Ambient Kiri Bawah
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Konten Tengah
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Kotak Logo DelCheck 120x120
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.check_circle_rounded,
                            size: 64,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Wordmark: DelCheck
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Del',
                            style: TextStyle(color: _textDark),
                          ),
                          TextSpan(
                            text: 'Check',
                            style: TextStyle(color: _primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tagline
                    const Text(
                      'Kelola pesanan, stok, dan pengiriman dengan mudah',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        height: 1.4,
                      ),
                    ),

                    const Spacer(flex: 4),

                    // Spinner Animasi & Teks Memuat
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _primary,
                        backgroundColor: Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Memuat...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Versi Aplikasi
                    const Text(
                      'DelCheck v1.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC3C6D7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}