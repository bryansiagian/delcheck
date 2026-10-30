import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/stok.dart';
import '../services/stok_service.dart';

/// Layar Detail Stok & Mutasi Produk Modern
class StokDetailScreen extends StatefulWidget {
  const StokDetailScreen({super.key, required this.stok});

  final StokProduk stok;

  @override
  State<StokDetailScreen> createState() => _StokDetailScreenState();
}

class _StokDetailScreenState extends State<StokDetailScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFEFF4FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF004AC6);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);
  static const Color _outline = Color(0xFF737686);

  static const Color _teal = Color(0xFF0D9488);
  static const Color _tealBg = Color(0xFFCCFBF1);

  static const Color _warningBg = Color(0xFFFFDBCA);
  static const Color _warningColor = Color(0xFF9D4300);
  static const Color _warningAccent = Color(0xFFFD761A);

  static const Color _errorBg = Color(0xFFFFDAD6);
  static const Color _errorColor = Color(0xFFBA1A1A);

  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController(text: '10');
  final _alasanCtrl = TextEditingController();

  late final StokService _service;
  late StokProduk _stok;

  bool _tambah = true; // true = Tambah, false = Kurangi
  bool _bekerja = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  final List<MutasiStok> _riwayat = [];
  int _halaman = 0;
  int _halamanTerakhir = 1;
  bool _memuatRiwayat = false;
  String? _errorRiwayat;

  String? _fe(String field) => _fieldErrors[field]?.first;

  @override
  void initState() {
    super.initState();
    _service = StokService(context.read<ApiClient>());
    _stok = widget.stok;
    _muatRiwayat();
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatRiwayat({bool lagi = false}) async {
    if (_memuatRiwayat) return;
    setState(() {
      _memuatRiwayat = true;
      _errorRiwayat = null;
    });
    try {
      final h =
          await _service.riwayat(_stok.id, halaman: lagi ? _halaman + 1 : 1);
      if (!mounted) return;
      setState(() {
        if (!lagi) _riwayat.clear();
        _riwayat.addAll(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorRiwayat = e.message);
    } finally {
      if (mounted) setState(() => _memuatRiwayat = false);
    }
  }

  void _aturJumlah(int delta) {
    int val = int.tryParse(_jumlahCtrl.text.trim()) ?? 0;
    val = (val + delta).clamp(1, 9999);
    setState(() {
      _jumlahCtrl.text = val.toString();
    });
  }

  void _setQuickVal(int val) {
    setState(() {
      _jumlahCtrl.text = val.toString();
    });
  }

  int _hitungHasilStok() {
    final qty = int.tryParse(_jumlahCtrl.text.trim()) ?? 0;
    if (_tambah) {
      return _stok.jumlah + qty;
    } else {
      final hasil = _stok.jumlah - qty;
      return hasil < 0 ? 0 : hasil;
    }
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _fieldErrors = {};
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final jumlah = int.parse(_jumlahCtrl.text.trim());
    final alasan = _alasanCtrl.text.trim();

    setState(() => _bekerja = true);
    try {
      final baru = await _service.ubah(
        _stok.id,
        tipe: _tambah ? 'masuk' : 'keluar',
        jumlah: jumlah,
        alasan: alasan.isEmpty ? null : alasan,
      );
      if (!mounted) return;
      setState(() {
        _stok = baru;
        _jumlahCtrl.text = '10';
        _alasanCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_tambah
            ? 'Stok bertambah ${formatAngka(jumlah)} ${_stok.satuan}.'
            : 'Stok berkurang ${formatAngka(jumlah)} ${_stok.satuan}.'),
      ));
      await _muatRiwayat();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.errors;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Styling Summary Card
    Color iconBg = const Color(0xFFD3E4FE);
    Color stockTextColor = _primary;
    String statusLabel = 'Aman';
    Color pillBg = const Color(0xFFDCE9FF);
    Color pillText = _primaryDark;
    double progressRatio = 1.0;
    Color progressBarColor = _primary;

    if (_stok.habis) {
      iconBg = _errorBg;
      stockTextColor = _errorColor;
      statusLabel = 'Habis';
      pillBg = _errorBg;
      pillText = _errorColor;
      progressRatio = 0.0;
      progressBarColor = _errorColor;
    } else if (_stok.menipis) {
      iconBg = _warningBg;
      stockTextColor = _warningAccent;
      statusLabel = 'Menipis';
      pillBg = _warningBg;
      pillText = _warningColor;
      progressRatio = 0.4;
      progressBarColor = _warningAccent;
    }

    final hasilStok = _hitungHasilStok();

    return Scaffold(
      backgroundColor: _bgSurface,
      body: Column(
        children: [
          // ================= 1. HEADER GRADIENT =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primary],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x29004AC6),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Detail Stok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ================= 2. CONTENT BODY =================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Error Banner
                if (_error != null && _fieldErrors.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _errorBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: _errorColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: _errorColor, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ================= CARD 1: RINGKASAN STOK =================
                Container(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                color: stockTextColor, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _stok.nama,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _stok.kode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _outline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: pillText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Big Stock Count
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatAngka(_stok.jumlah),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: stockTextColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _stok.satuan,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress Bar
                      Container(
                        width: double.infinity,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EEFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: progressBarColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 15, color: _outline),
                          const SizedBox(width: 6),
                          Text(
                            'Minimum stok: ${formatAngka(_stok.stokMinimum)} ${_stok.satuan}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ================= CARD 2: PERBARUI STOK =================
                Container(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Perbarui Stok',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Segmented Control (Tambah / Kurangi)
                        Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5EEFF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _bekerja
                                      ? null
                                      : () => setState(() {
                                            _tambah = true;
                                            _fieldErrors = {};
                                            _error = null;
                                          }),
                                  borderRadius: BorderRadius.circular(11),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _tambah
                                          ? _primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: _tambah
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add,
                                            size: 16,
                                            color: _tambah
                                                ? Colors.white
                                                : _textDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Tambah',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _tambah
                                                ? Colors.white
                                                : _textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: _bekerja
                                      ? null
                                      : () => setState(() {
                                            _tambah = false;
                                            _fieldErrors = {};
                                            _error = null;
                                          }),
                                  borderRadius: BorderRadius.circular(11),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: !_tambah
                                          ? _primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: !_tambah
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.remove,
                                            size: 16,
                                            color: !_tambah
                                                ? Colors.white
                                                : _textDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Kurangi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: !_tambah
                                                ? Colors.white
                                                : _textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stepper Field
                        const Text(
                          'Jumlah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _aturJumlah(-1),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5EEFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.remove,
                                    color: _textDark, size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF4FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        controller: _jumlahCtrl,
                                        enabled: !_bekerja,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    Text(
                                      _stok.satuan,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _aturJumlah(1),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5EEFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add,
                                    color: _textDark, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick Chips
                        Row(
                          children: [10, 50, 100].map((val) {
                            final sign = _tambah ? '+' : '−';
                            final isSelected =
                                _jumlahCtrl.text.trim() == val.toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => _setQuickVal(val),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? _primary
                                          : const Color(0xFFE5EEFF),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$sign$val',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : _textDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Preview Box (Stok Setelah Perubahan)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5EEFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Stok setelah perubahan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${_stok.jumlah}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _textDark,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: '  →  ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _outline,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '$hasilStok ${_stok.satuan}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _tambah ? _teal : _warningColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        Text(
                          _tambah ? 'Catatan (opsional)' : 'Alasan (wajib)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _alasanCtrl,
                          enabled: !_bekerja,
                          maxLength: 255,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFEFF4FF),
                            hintText: _tambah
                                ? 'Contoh: barang datang dari pemasok'
                                : 'Contoh: barang rusak, salah hitung',
                            hintStyle: const TextStyle(
                                color: _outline, fontSize: 13),
                            errorText: _fe('alasan'),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) {
                            if (!_tambah && (v ?? '').trim().isEmpty) {
                              return 'Alasan wajib diisi saat mengurangi stok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _bekerja ? null : _simpan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: _bekerja
                                ? const SizedBox()
                                : Icon(_tambah ? Icons.add : Icons.remove,
                                    size: 18),
                            label: _bekerja
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _tambah ? 'Tambah stok' : 'Kurangi stok',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ================= 3. SECTION RIWAYAT STOK =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat stok',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      '${_riwayat.length} mutasi tercatat',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Timeline Card
                Container(
                  padding: const EdgeInsets.all(18),
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
                  child: _buildRiwayatContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatContent() {
    if (_errorRiwayat != null) {
      return Center(
        child: Column(
          children: [
            Text(_errorRiwayat!, style: const TextStyle(color: _errorColor)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _muatRiwayat,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_memuatRiwayat && _riwayat.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary)),
      );
    }

    if (_riwayat.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 40, color: Color(0xFFCBD5E1)),
              SizedBox(height: 8),
              Text(
                'Belum ada riwayat mutasi stok.',
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _riwayat.length; i++) ...[
          _buildTimelineItem(
            m: _riwayat[i],
            satuan: _stok.satuan,
            isLast: i == _riwayat.length - 1,
          ),
        ],
        if (_halaman < _halamanTerakhir)
          Center(
            child: TextButton(
              onPressed: _memuatRiwayat ? null : () => _muatRiwayat(lagi: true),
              child: _memuatRiwayat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Muat lebih banyak'),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required MutasiStok m,
    required String satuan,
    required bool isLast,
  }) {
    final isMasuk = m.masuk;
    final iconBg = isMasuk ? _tealBg : _warningBg;
    final iconColor = isMasuk ? _teal : _warningColor;
    final sign = isMasuk ? '+' : '−';

    return Stack(
      children: [
        // Garis timeline vertikal
        if (!isLast)
          Positioned(
            left: 17,
            top: 24,
            bottom: 0,
            child: Container(
              width: 2,
              color: const Color(0xFFE5EEFF),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circle Icon
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(
                  isMasuk ? Icons.add_rounded : Icons.remove_rounded,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),

              // Detail Mutasi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$sign${formatAngka(m.jumlah.abs())} $satuan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                        Text(
                          'Sisa ${formatAngka(m.stokSesudah)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.alasan ?? (isMasuk ? 'Penambahan stok' : 'Pengurangan stok'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textDark,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (m.oleh != null) 'oleh ${m.oleh}',
                        if (m.dibuat != null) formatTanggalJam(m.dibuat!),
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: _outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}