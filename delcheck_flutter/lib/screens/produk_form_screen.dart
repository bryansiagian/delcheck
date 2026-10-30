import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/produk.dart';
import '../services/produk_service.dart';

/// Form tambah / ubah produk dengan desain Tailwind Modern
class ProdukFormScreen extends StatefulWidget {
  const ProdukFormScreen({super.key, this.produk});

  final Produk? produk;

  @override
  State<ProdukFormScreen> createState() => _ProdukFormScreenState();
}

class _ProdukFormScreenState extends State<ProdukFormScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);
  static const Color _outline = Color(0xFF737686);
  static const Color _inputBg = Color(0xFFEFF4FF);

  static const _satuanUmum = ['pcs', 'dus', 'pak', 'botol', 'kg', 'liter'];

  final _formKey = GlobalKey<FormState>();
  final _kodeCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _satuanCtrl = TextEditingController(text: 'dus');
  final _hargaCtrl = TextEditingController();
  final _stokMinCtrl = TextEditingController(text: '10');
  final _deskripsiCtrl = TextEditingController();

  late final ProdukService _service;
  bool _aktif = true;
  bool _bekerja = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  bool get _edit => widget.produk != null;
  String? _fe(String field) => _fieldErrors[field]?.first;

  @override
  void initState() {
    super.initState();
    _service = ProdukService(context.read<ApiClient>());

    final p = widget.produk;
    if (p != null) {
      _kodeCtrl.text = p.kode;
      _namaCtrl.text = p.nama;
      _satuanCtrl.text = p.satuan;
      _hargaCtrl.text = p.harga == p.harga.roundToDouble()
          ? p.harga.round().toString()
          : p.harga.toStringAsFixed(2);
      _stokMinCtrl.text = p.stokMinimum.toString();
      _deskripsiCtrl.text = p.deskripsi ?? '';
      _aktif = p.aktif;
    }
  }

  @override
  void dispose() {
    _kodeCtrl.dispose();
    _namaCtrl.dispose();
    _satuanCtrl.dispose();
    _hargaCtrl.dispose();
    _stokMinCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  void _ubahStokMinimum(int delta) {
    int saatIni = int.tryParse(_stokMinCtrl.text.trim()) ?? 0;
    saatIni += delta;
    if (saatIni < 0) saatIni = 0;
    setState(() {
      _stokMinCtrl.text = saatIni.toString();
    });
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _fieldErrors = {};
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final deskripsi = _deskripsiCtrl.text.trim();
    final data = <String, dynamic>{
      'kode': _kodeCtrl.text.trim(),
      'nama': _namaCtrl.text.trim(),
      'satuan': _satuanCtrl.text.trim(),
      'harga': double.parse(_hargaCtrl.text.trim()),
      'stok_minimum': int.tryParse(_stokMinCtrl.text.trim()) ?? 0,
      'deskripsi': deskripsi.isEmpty ? null : deskripsi,
      'is_active': _aktif,
    };

    setState(() => _bekerja = true);
    try {
      if (_edit) {
        await _service.ubah(widget.produk!.id, data);
      } else {
        await _service.tambah(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_edit ? 'Produk berhasil diperbarui.' : 'Produk berhasil ditambahkan.'),
        ),
      );
      Navigator.pop(context, true);
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

  Future<void> _hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus produk?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '${widget.produk!.nama} akan dihapus dari katalog. '
          'Untuk menyembunyikan sementara, Anda cukup menonaktifkan status produk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _bekerja = true);
    try {
      final pesan = await _service.hapus(widget.produk!.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(pesan)));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: Column(
        children: [
          // ================= 1. HEADER BIRU GRADIENT =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_primaryDark, Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x291D4ED8),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _edit ? 'Ubah Produk' : 'Tambah Produk Baru',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Lengkapi detail inventaris & harga',
                        style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_edit)
                  IconButton(
                    onPressed: _bekerja ? null : _hapus,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 22),
                    tooltip: 'Hapus Produk',
                  ),
              ],
            ),
          ),

          // ================= 2. FORM BODY DENGAN CARD-CARD =================
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Error Banner jika ada error API
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFBA1A1A), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Color(0xFFBA1A1A), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notice Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: _primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _edit ? 'Edit SKU Produk' : 'Input SKU Baru',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                ),
                                const Text(
                                  'Katalog inventaris & gudang',
                                  style: TextStyle(
                                      fontSize: 11, color: _textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE9FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                  radius: 3,
                                  backgroundColor: Color(0xFFFD761A)),
                              SizedBox(width: 5),
                              Text(
                                'Katalog DelCheck',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================= CARD 1: INFORMASI PRODUK =================
                  _buildFormCard(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFDCE9FF),
                    iconColor: _primary,
                    title: 'Informasi Produk',
                    subtitle: 'Identitas barang dan pelabelan inventaris',
                    children: [
                      // Kode Produk
                      _buildHeaderLabel('Kode Produk', wajib: true),
                      TextFormField(
                        controller: _kodeCtrl,
                        enabled: !_bekerja,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecor(
                          hint: 'Contoh: MIE-001',
                          icon: Icons.sell_outlined,
                          errorText: _fe('kode'),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Kode wajib diisi';
                          if (t.length > 40) return 'Maksimal 40 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Unik, tanpa spasi (disarankan pakai strip pemisah)',
                        style: TextStyle(fontSize: 11, color: _outline),
                      ),
                      const SizedBox(height: 16),

                      // Nama Produk
                      _buildHeaderLabel('Nama Produk', wajib: true),
                      TextFormField(
                        controller: _namaCtrl,
                        enabled: !_bekerja,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecor(
                          hint: 'Contoh: Mi Instan Goreng Spesial',
                          icon: Icons.shopping_bag_outlined,
                          errorText: _fe('nama'),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Nama produk wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi
                      _buildHeaderLabel('Deskripsi (Opsional)'),
                      TextFormField(
                        controller: _deskripsiCtrl,
                        enabled: !_bekerja,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecor(
                          hint: 'Keterangan rasa, varian, atau penyimpanan...',
                          icon: Icons.notes_rounded,
                          alignTop: true,
                          errorText: _fe('deskripsi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= CARD 2: HARGA DAN SATUAN =================
                  _buildFormCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: const Color(0xFFFFDBCA),
                    iconColor: const Color(0xFF9D4300),
                    title: 'Harga dan Satuan',
                    subtitle: 'Penetapan batas harga jual logistik',
                    children: [
                      _buildHeaderLabel('Satuan Unit Terpilih', wajib: true),
                      TextFormField(
                        controller: _satuanCtrl,
                        enabled: !_bekerja,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecor(
                          hint: 'Pilih atau ketik satuan',
                          icon: Icons.straighten_rounded,
                          errorText: _fe('satuan'),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Satuan wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      // Quick Pick Chips
                      const Text(
                        'Rekomendasi Satuan Grosir',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _satuanUmum) ...[
                            InkWell(
                              onTap: _bekerja
                                  ? null
                                  : () {
                                      setState(() {
                                        _satuanCtrl.text = s;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _satuanCtrl.text.toLowerCase() == s
                                      ? _primary
                                      : const Color(0xFFDCE9FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_satuanCtrl.text.toLowerCase() == s) ...[
                                      const Icon(Icons.check,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _satuanCtrl.text.toLowerCase() == s
                                            ? Colors.white
                                            : _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Harga
                      _buildHeaderLabel('Harga Grosir / Satuan', wajib: true),
                      TextFormField(
                        controller: _hargaCtrl,
                        enabled: !_bekerja,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: _inputDecor(
                          hint: '0',
                          prefixText: 'Rp  ',
                          errorText: _fe('harga'),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Harga wajib diisi';
                          if (double.tryParse(t) == null) return 'Harga tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Harga berlaku per ${_satuanCtrl.text.isEmpty ? "unit" : _satuanCtrl.text} saat pembuatan pesanan',
                        style: const TextStyle(fontSize: 11, color: _outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= CARD 3: PENGATURAN STOK =================
                  _buildFormCard(
                    icon: Icons.layers_outlined,
                    iconBg: const Color(0xFFDCE9FF),
                    iconColor: _primary,
                    title: 'Pengaturan Stok',
                    subtitle: 'Batas aman ketersediaan gudang pusat',
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _inputBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Batas Stok Minimum',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                ),
                                Text(
                                  'Ambang pemicu restock',
                                  style: TextStyle(
                                      fontSize: 11, color: _textMuted),
                                ),
                              ],
                            ),
                            // Stepper
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _ubahStokMinimum(-1),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _inputBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.remove, size: 16),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      _stokMinCtrl.text,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _ubahStokMinimum(1),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _inputBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDBCA).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFF9D4300), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Peringatan stok menipis otomatis aktif jika jumlah barang di bawah angka ini.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF783200),
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ================= CARD 4: STATUS PRODUK =================
                  _buildFormCard(
                    icon: Icons.visibility_outlined,
                    iconBg: const Color(0xFFDBE1FF),
                    iconColor: _primary,
                    title: 'Status Distribusi',
                    subtitle: 'Visibilitas pada aplikasi kurir & sales',
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _aktif ? 'Produk Aktif' : 'Produk Nonaktif',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                ),
                                const Text(
                                  'Produk nonaktif tidak tampil untuk retail dan pesanan sales',
                                  style: TextStyle(
                                      fontSize: 11, color: _textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _aktif,
                            activeColor: _primary,
                            onChanged: _bekerja
                                ? null
                                : (v) => setState(() => _aktif = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ================= 3. BOTTOM ACTION BAR MELAYANG =================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
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
                : const Icon(Icons.task_alt_rounded, size: 20),
            label: _bekerja
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    _edit ? 'Simpan Perubahan' : 'Simpan & Verifikasi',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Card Kontainer Form ---
  Widget _buildFormCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHeaderLabel(String text, {bool wajib = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          if (wajib)
            const Text(
              'WAJIB',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _primary,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor({
    required String hint,
    IconData? icon,
    String? prefixText,
    String? errorText,
    bool alignTop = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _inputBg,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _textDark,
      ),
      errorText: errorText,
      hintStyle: const TextStyle(color: _outline, fontSize: 13),
      prefixIcon: icon != null
          ? Padding(
              padding: EdgeInsets.only(bottom: alignTop ? 40 : 0),
              child: Icon(icon, color: _outline, size: 20),
            )
          : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }
}