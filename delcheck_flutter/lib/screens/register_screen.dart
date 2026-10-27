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
    for (final c in [_name, _email, _phone, _password, _namaToko, _namaPemilik, _alamat]) {
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

  /// Wilayah terdalam yang dipilih; boleh null (wilayah_id nullable di server).
  int? get _wilayahId => _kecamatanId ?? _kotaId ?? _provinsiId;

  // ---------- Submit ----------

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _submit() async {
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
        MaterialPageRoute(builder: (_) => RegisterSuccessScreen(message: message)),
      );
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _formError = e.fieldErrors.isEmpty ? e.message : null;
      });
      _formKey.currentState!.validate(); // tampilkan error server di tiap field
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
    if (email.isEmpty && _phone.text.trim().isEmpty) return 'Isi email atau nomor telepon.';
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Format email tidak valid.';
    }
    return _serverErrors['email'];
  }

  String? _validatePhone(String? v) {
    final phone = v?.trim() ?? '';
    if (phone.isEmpty && _email.text.trim().isEmpty) return 'Isi email atau nomor telepon.';
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

  // ---------- UI ----------

  Widget _wilayahDropdown({
    required String label,
    required List<Wilayah> items,
    required int? value,
    required bool loading,
    required ValueChanged<int?>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      // ignore: deprecated_member_use
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : null,
      ),
      items: items
          .map((w) => DropdownMenuItem<int>(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: loading || _submitting ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar sebagai toko')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_formError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_formError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),

              Text('Data akun', style: Theme.of(context).textTheme.titleMedium),
              gap,
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama lengkap', border: OutlineInputBorder()),
                validator: (v) => _required(v, 'Nama', 'name'),
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: _validateEmail,
              ),
              gap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nomor telepon',
                  hintText: '0812xxxxxxxx',
                  helperText: 'Isi email atau nomor telepon (minimal salah satu).',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
              ),
              gap,
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  helperText: 'Minimal 8 karakter, kombinasi huruf dan angka.',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _validatePassword,
              ),

              const SizedBox(height: 24),
              Text('Data toko', style: Theme.of(context).textTheme.titleMedium),
              gap,
              TextFormField(
                controller: _namaToko,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama toko', border: OutlineInputBorder()),
                validator: (v) => _required(v, 'Nama toko', 'nama_toko'),
              ),
              gap,
              TextFormField(
                controller: _namaPemilik,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama pemilik (opsional)', border: OutlineInputBorder()),
                validator: (_) => _serverErrors['nama_pemilik'],
              ),
              gap,
              TextFormField(
                controller: _alamat,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(labelText: 'Alamat lengkap', border: OutlineInputBorder()),
                validator: (v) => _required(v, 'Alamat', 'alamat'),
              ),
              gap,
              _wilayahDropdown(
                label: 'Provinsi',
                items: _provinsi,
                value: _provinsiId,
                loading: _loadingProvinsi,
                onChanged: _onProvinsiChanged,
              ),
              gap,
              _wilayahDropdown(
                label: 'Kota/Kabupaten',
                items: _kota,
                value: _kotaId,
                loading: _loadingKota,
                onChanged: _provinsiId == null ? null : _onKotaChanged,
              ),
              gap,
              _wilayahDropdown(
                label: 'Kecamatan',
                items: _kecamatan,
                value: _kecamatanId,
                loading: _loadingKecamatan,
                onChanged: _kotaId == null ? null : (id) => setState(() => _kecamatanId = id),
              ),
              if (_wilayahError != null || _serverErrors['wilayah_id'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _wilayahError ?? _serverErrors['wilayah_id']!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                      if (_wilayahError != null && _provinsi.isEmpty)
                        TextButton(onPressed: _loadProvinsi, child: const Text('Coba lagi')),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Daftar'),
              ),
              const SizedBox(height: 8),
              Text(
                'Akun toko akan diverifikasi admin sebelum bisa digunakan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
