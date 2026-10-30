import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identitasCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _sembunyikan = true;
  bool _memuat = false;
  String? _error;

  // Palet Warna persis sesuai kode HTML (Tailwind Config)
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color _surfaceCard = Colors.white;
  static const Color _primary = Color(0xFF2563EB); // primary-container
  static const Color _textMain = Color(0xFF0B1C30); // on-surface
  static const Color _textMuted = Color(0xFF4D556B); // tertiary
  static const Color _outline = Color(0xFF737686); // outline
  static const Color _errorColor = Color(0xFFBA1A1A);
  static const Color _errorContainer = Color(0xFFFFDAD6);

  @override
  void dispose() {
    _identitasCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _memuat = true;
      _error = null;
    });

    try {
      await context
          .read<AuthProvider>()
          .login(_identitasCtrl.text.trim(), _passwordCtrl.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _bukaDaftar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ---------------- HEADER BIRU MUDA ----------------
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                child: Column(
                  children: [
                    // Kotak Logo
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.check_circle_rounded,
                                  size: 40, color: _primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Teks Brand DelCheck
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Del',
                            style: TextStyle(color: _textMain),
                          ),
                          TextSpan(
                            text: 'Check',
                            style: TextStyle(color: _primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kelola pesanan, stok, dan pengiriman dengan mudah',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------- KARTU FORM LOGIN (MELAYANG) ----------------
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surfaceCard,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCBDBF5).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat datang kembali',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Masuk untuk melanjutkan ke akun Anda',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error State Box
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 20, color: _errorColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: _errorColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Input Email / Telepon
                        const Text(
                          'Email atau Telepon',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _identitasCtrl,
                          enabled: !_memuat,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _surfaceContainerLow,
                            hintText: 'nama@perusahaan.com',
                            hintStyle: const TextStyle(
                                color: _outline, fontSize: 14),
                            prefixIcon: const Icon(Icons.mail_outline,
                                color: _textMuted, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: _primary, width: 2),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Email atau telepon wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Input Kata Sandi
                        const Text(
                          'Kata sandi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordCtrl,
                          enabled: !_memuat,
                          obscureText: _sembunyikan,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _masuk(),
                          style: const TextStyle(
                              color: _textMain, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _surfaceContainerLow,
                            hintText: 'Masukkan kata sandi',
                            hintStyle: const TextStyle(
                                color: _outline, fontSize: 14),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: _textMuted, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sembunyikan
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _sembunyikan = !_sembunyikan),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: _primary, width: 2),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Kata sandi wajib diisi'
                              : null,
                        ),

                        // Lupa kata sandi
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Silakan hubungi administrator untuk mereset sandi.'),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Lupa kata sandi?',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tombol Masuk
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _memuat ? null : _masuk,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _primary.withOpacity(0.6),
                              elevation: 2,
                              shadowColor: _primary.withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _memuat
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ---------------- FOOTER & HUBUNGI ADMIN / DAFTAR ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun? ',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                    GestureDetector(
                      onTap: _bukaDaftar,
                      child: const Text(
                        'Daftar sebagai toko',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'DelCheck v1.0',
                style: TextStyle(
                  fontSize: 11,
                  color: _outline,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}