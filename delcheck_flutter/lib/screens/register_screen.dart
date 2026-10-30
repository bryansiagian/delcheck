import 'package:flutter/material.dart';

import '../models/wilayah.dart';
import '../services/register_service.dart';
import 'register_success_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _headerBg = Color(0xFFEFF4FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF434655);
  static const Color _outline = Color(0xFF737686);
  static const Color _successGreen = Color(0xFF16A34A);

  final _service = RegisterService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _namaToko = TextEditingController();
  final _namaPemilik = TextEditingController();
  final _alamat = TextEditingController();

  // Wilayah bertingkat
  List<Wilayah> _provinsi = [];
  List<Wilayah> _kota = [];
  List<Wilayah> _kecamatan = [];
  int? _provinsiId;
  int? _kotaId;
  int? _kecamatanId;
  bool _loadingProvinsi = true;
  bool _loadingKota = false;
  bool _loadingKecamatan = false;
  String? _wilayahError;

  bool _obscure = true;
  bool _submitting = false;
  String? _formError;
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _loadProvinsi();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _password,
      _namaToko,
      _namaPemilik,
      _alamat
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Wilayah ----------

  Future<void> _loadProvinsi() async {
    setState(() {
      _loadingProvinsi = true;
      _wilayahError = null;
    });
    try {
      final data = await _service.fetchWilayah(tingkat: 'provinsi');
      if (!mounted) return;
      setState(() => _provinsi = data);
    } on RegisterException catch (e) {
      if (mounted) setState(() => _wilayahError = e.message);
    } finally {
      if (mounted) setState(() => _loadingProvinsi = false);
    }
  }

  Future<void> _onProvinsiChanged(int? id) async {
    setState(() {
      _provinsiId = id;
      _kotaId = null;
      _kecamatanId = null;
      _kota = [];
      _kecamatan = [];
      _loadingKota = id != null;
      _wilayahError = null;
    });
    if (id == null) return;
    try {
      final data = await _service.fetchWilayah(parentId: id);
      if (!mounted) return;
      setState(() => _kota = data);
    } on RegisterException catch (e) {
      if (mounted) setState(() => _wilayahError = e.message);
    } finally {
      if (mounted) setState(() => _loadingKota = false);
    }
  }

  Future<void> _onKotaChanged(int? id) async {
    setState(() {
      _kotaId = id;
      _kecamatanId = null;
      _kecamatan = [];
      _loadingKecamatan = id != null;
      _wilayahError = null;
    });
    if (id == null) return;
    try {
      final data = await _service.fetchWilayah(parentId: id);
      if (!mounted) return;
      setState(() => _kecamatan = data);
    } on RegisterException catch (e) {
      if (mounted) setState(() => _wilayahError = e.message);
    } finally {
      if (mounted) setState(() => _loadingKecamatan = false);
    }
  }

  int? get _wilayahId => _kecamatanId ?? _kotaId ?? _provinsiId;

  // ---------- Submit ----------

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _serverErrors = {};
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final message = await _service.register(RegisterPayload(
        name: _name.text.trim(),
        email: _nullIfEmpty(_email.text),
        phone: _nullIfEmpty(_phone.text),
        password: _password.text,
        namaToko: _namaToko.text.trim(),
        namaPemilik: _nullIfEmpty(_namaPemilik.text),
        alamat: _alamat.text.trim(),
        wilayahId: _wilayahId,
      ));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => RegisterSuccessScreen(message: message)),
      );
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _formError = e.fieldErrors.isEmpty ? e.message : null;
      });
      _formKey.currentState!.validate();
    } on RegisterException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------- Validator ----------

  String? _required(String? v, String label, String serverKey) {
    if (v == null || v.trim().isEmpty) return '$label wajib diisi.';
    return _serverErrors[serverKey];
  }

  String? _validateEmail(String? v) {
    final email = v?.trim() ?? '';
    if (email.isEmpty && _phone.text.trim().isEmpty) {
      return 'Isi email atau nomor telepon.';
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Format email tidak valid.';
    }
    return _serverErrors['email'];
  }

  String? _validatePhone(String? v) {
    final phone = v?.trim() ?? '';
    if (phone.isEmpty && _email.text.trim().isEmpty) {
      return 'Isi email atau nomor telepon.';
    }
    return _serverErrors['phone'];
  }

  String? _validatePassword(String? v) {
    final p = v ?? '';
    if (p.length < 8) return 'Kata sandi minimal 8 karakter.';
    if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'[0-9]').hasMatch(p)) {
      return 'Kata sandi harus mengandung huruf dan angka.';
    }
    return _serverErrors['password'];
  }

  // Pengecekan real-time untuk checklist password
  bool get _hasMin8 => _password.text.length >= 8;
  bool get _hasLetterAndNum =>
      RegExp(r'[A-Za-z]').hasMatch(_password.text) &&
      RegExp(r'[0-9]').hasMatch(_password.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ================= 1. HEADER AREA =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                decoration: const BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: _textDark, size: 22),
                          ),
                        ),
                        // Logo DelCheck
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.check_circle_rounded,
                                  color: _primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Daftar sebagai toko',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buat akun toko untuk mulai memesan barang',
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                  ],
                ),
              ),

              // ================= 2. FORM BODY =================
              Transform.translate(
                offset: const Offset(0, -18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Error Banner
                        if (_formError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDAD6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFBA1A1A), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_formError!,
                                      style: const TextStyle(
                                          color: Color(0xFFBA1A1A),
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ================= CARD 1: DATA AKUN =================
                        _buildFormCard(
                          step: '1',
                          title: 'Data akun',
                          subtitle: 'Untuk masuk ke aplikasi',
                          children: [
                            // Nama Lengkap
                            _buildInputLabel('Nama lengkap'),
                            TextFormField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecor(
                                hint: 'Masukkan nama lengkap',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (v) =>
                                  _required(v, 'Nama', 'name'),
                            ),
                            const SizedBox(height: 14),

                            // Email
                            _buildInputLabel('Email'),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecor(
                                hint: 'nama@email.com',
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),

                            // Nomor Telepon
                            _buildInputLabel('Nomor telepon'),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecor(
                                hint: '08xxxxxxxxxx',
                                icon: Icons.call_outlined,
                              ),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 10),

                            // Info Box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBE1FF).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: _primary, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Isi email atau nomor telepon, minimal salah satu.',
                                      style: TextStyle(
                                          color: _primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Kata Sandi
                            _buildInputLabel('Kata sandi'),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecor(
                                hint: 'Buat kata sandi',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _outline,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 10),

                            // Checklist Kata Sandi Dinamis
                            _buildChecklistRow(
                              text: 'Minimal 8 karakter',
                              checked: _hasMin8,
                            ),
                            const SizedBox(height: 4),
                            _buildChecklistRow(
                              text: 'Kombinasi huruf dan angka',
                              checked: _hasLetterAndNum,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ================= CARD 2: DATA TOKO =================
                        _buildFormCard(
                          step: '2',
                          title: 'Data toko',
                          subtitle: 'Alamat untuk pengiriman pesanan',
                          children: [
                            // Nama Toko
                            _buildInputLabel('Nama toko'),
                            TextFormField(
                              controller: _namaToko,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecor(
                                hint: 'Contoh: Toko Maju Jaya',
                                icon: Icons.storefront_outlined,
                              ),
                              validator: (v) =>
                                  _required(v, 'Nama toko', 'nama_toko'),
                            ),
                            const SizedBox(height: 14),

                            // Nama Pemilik
                            _buildInputLabel('Nama pemilik (opsional)'),
                            TextFormField(
                              controller: _namaPemilik,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecor(
                                hint: 'Contoh: Budi Santoso',
                                icon: Icons.badge_outlined,
                              ),
                              validator: (_) =>
                                  _serverErrors['nama_pemilik'],
                            ),
                            const SizedBox(height: 14),

                            // Alamat Lengkap
                            _buildInputLabel('Alamat lengkap'),
                            TextFormField(
                              controller: _alamat,
                              maxLines: 3,
                              textInputAction: TextInputAction.newline,
                              decoration: _inputDecor(
                                hint: 'Jalan, nomor ruko/toko, patokan...',
                                icon: Icons.location_on_outlined,
                                alignTop: true,
                              ),
                              validator: (v) =>
                                  _required(v, 'Alamat', 'alamat'),
                            ),
                            const SizedBox(height: 14),

                            // Wilayah: Provinsi
                            _buildInputLabel('Provinsi'),
                            _buildDropdownWilayah(
                              hint: 'Pilih Provinsi',
                              items: _provinsi,
                              value: _provinsiId,
                              loading: _loadingProvinsi,
                              onChanged: _onProvinsiChanged,
                            ),
                            const SizedBox(height: 14),

                            // Wilayah: Kota/Kabupaten
                            _buildInputLabel('Kota / Kabupaten'),
                            _buildDropdownWilayah(
                              hint: 'Pilih Kota / Kabupaten',
                              items: _kota,
                              value: _kotaId,
                              loading: _loadingKota,
                              onChanged: _provinsiId == null
                                  ? null
                                  : _onKotaChanged,
                            ),
                            const SizedBox(height: 14),

                            // Wilayah: Kecamatan
                            _buildInputLabel('Kecamatan'),
                            _buildDropdownWilayah(
                              hint: 'Pilih Kecamatan',
                              items: _kecamatan,
                              value: _kecamatanId,
                              loading: _loadingKecamatan,
                              onChanged: _kotaId == null
                                  ? null
                                  : (id) =>
                                      setState(() => _kecamatanId = id),
                            ),
                            if (_wilayahError != null ||
                                _serverErrors['wilayah_id'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _wilayahError ??
                                            _serverErrors['wilayah_id']!,
                                        style: const TextStyle(
                                            color: Color(0xFFBA1A1A),
                                            fontSize: 12),
                                      ),
                                    ),
                                    if (_wilayahError != null &&
                                        _provinsi.isEmpty)
                                      TextButton(
                                        onPressed: _loadProvinsi,
                                        child: const Text('Coba lagi'),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ================= 3. VERIFICATION BANNER =================
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDBCA).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined,
                                  color: Color(0xFF9D4300), size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Perlu verifikasi admin',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9D4300),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Akun toko akan diverifikasi admin sebelum bisa digunakan untuk memesan barang.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5C2400),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ================= 4. SUBMIT CTA =================
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Daftar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Link Kembali ke Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Sudah punya akun? ',
                              style: TextStyle(
                                  fontSize: 13, color: _textMuted),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Masuk',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Card Step Container ---
  Widget _buildFormCard({
    required String step,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
      ),
    );
  }

  InputDecoration _inputDecor({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    bool alignTop = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(color: _outline, fontSize: 13),
      prefixIcon: Padding(
        padding: EdgeInsets.only(bottom: alignTop ? 40 : 0),
        child: Icon(icon, color: _textMuted, size: 20),
      ),
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }

  Widget _buildChecklistRow({required String text, required bool checked}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: checked ? _successGreen : const Color(0xFFC3C6D7),
            shape: BoxShape.circle,
          ),
          child: checked
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: checked ? _successGreen : _textMuted,
            fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWilayah({
    required String hint,
    required List<Wilayah> items,
    required int? value,
    required bool loading,
    required ValueChanged<int?>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: _outline, fontSize: 13),
        prefixIcon: const Icon(Icons.map_outlined, color: _textMuted, size: 20),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
      items: items
          .map((w) => DropdownMenuItem<int>(
                value: w.id,
                child: Text(w.nama,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: loading || _submitting ? null : onChanged,
    );
  }
}