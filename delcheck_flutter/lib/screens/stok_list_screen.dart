import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/stok.dart';
import '../services/stok_service.dart';
import 'stok_detail_screen.dart';

/// Daftar stok semua produk untuk Admin dan Warehouse dengan UI modern
class StokListScreen extends StatefulWidget {
  const StokListScreen({super.key});

  @override
  State<StokListScreen> createState() => _StokListScreenState();
}

class _StokListScreenState extends State<StokListScreen> {
  // Palet Warna sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);
  static const Color _outline = Color(0xFF737686);

  static const Color _warningBg = Color(0xFFFFDBCA);
  static const Color _warningColor = Color(0xFF9D4300);
  static const Color _warningBar = Color(0xFFFD761A);

  static const Color _errorBg = Color(0xFFFFDAD6);
  static const Color _errorColor = Color(0xFFBA1A1A);

  late final StokService _service;
  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  Timer? _debounce;

  final List<StokProduk> _items = [];
  bool _hanyaMenipis = false;
  String _q = '';
  int _halaman = 0;
  int _halamanTerakhir = 1;
  int _total = 0;
  int _totalMenipisCount = 0;
  int _reqId = 0;

  bool _memuat = false;
  bool _memuatLagi = false;
  String? _error;

  bool get _adaLagi => _halaman < _halamanTerakhir;

  @override
  void initState() {
    super.initState();
    _service = StokService(context.read<ApiClient>());
    _scroll.addListener(_onScroll);
    _muatAwal();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _cariCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _muatLagi();
    }
  }

  Future<void> _muatAwal() async {
    final id = ++_reqId;
    setState(() {
      _memuat = true;
      _error = null;
    });

    try {
      final h = await _service.daftar(
          q: _q, menipis: _hanyaMenipis, halaman: 1);
      if (!mounted || id != _reqId) return;

      setState(() {
        _items
          ..clear()
          ..addAll(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
        _total = h.total;
      });

      // Ambil juga hitungan produk menipis untuk badge tab jika sedang di tab semua
      if (!_hanyaMenipis) {
        _service.daftar(menipis: true, halaman: 1).then((res) {
          if (mounted) {
            setState(() => _totalMenipisCount = res.total);
          }
        }).catchError((_) {});
      } else {
        _totalMenipisCount = h.total;
      }
    } on ApiException catch (e) {
      if (mounted && id == _reqId) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _reqId) setState(() => _memuat = false);
    }
  }

  Future<void> _muatLagi() async {
    if (_memuat || _memuatLagi || !_adaLagi) return;
    final id = _reqId;
    setState(() => _memuatLagi = true);
    try {
      final h = await _service.daftar(
          q: _q, menipis: _hanyaMenipis, halaman: _halaman + 1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  void _gantiFilter(bool menipis) {
    if (menipis == _hanyaMenipis) return;
    setState(() {
      _hanyaMenipis = menipis;
      _items.clear();
    });
    _muatAwal();
  }

  void _onCari(String teks) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (teks.trim() == _q) return;
      setState(() {
        _q = teks.trim();
        _items.clear();
      });
      _muatAwal();
    });
  }

  Future<void> _buka(StokProduk stok) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StokDetailScreen(stok: stok)),
    );
    if (mounted) _muatAwal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: Column(
        children: [
          // ================= 1. HEADER BIRU GRADIENT =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 36),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x291D4ED8),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stok Produk',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pantau dan perbarui jumlah stok',
                              style: TextStyle(
                                color: Color(0xFFDBEAFE),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _cariCtrl,
                    onChanged: (v) {
                      setState(() {});
                      _onCari(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk atau SKU',
                      hintStyle:
                          const TextStyle(color: _outline, fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: _outline, size: 22),
                      suffixIcon: _cariCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _cariCtrl.clear();
                                _onCari('');
                                setState(() {});
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================= 2. DUAL INTERACTIVE TILES MELAYANG =================
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Tile 1: Semua Produk
                    Expanded(
                      child: InkWell(
                        onTap: () => _gantiFilter(false),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: !_hanyaMenipis
                                ? const Color(0xFFE5EEFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD3E4FE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.layers_rounded,
                                        color: _primary, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Semua produk',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _primary,
                                          ),
                                        ),
                                        Text(
                                          'Katalog aktif',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    !_hanyaMenipis ? '$_total' : '-',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _primary,
                                    ),
                                  ),
                                ],
                              ),
                              if (!_hanyaMenipis)
                                Positioned(
                                  bottom: 0,
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFFE5EEFF)),
                    // Tile 2: Menipis / Habis
                    Expanded(
                      child: InkWell(
                        onTap: () => _gantiFilter(true),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _hanyaMenipis
                                ? _warningBg.withOpacity(0.5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: _warningBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: _warningColor,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Menipis / habis',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _textDark,
                                          ),
                                        ),
                                        Text(
                                          'Perlu restok',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$_totalMenipisCount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _warningColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (_hanyaMenipis)
                                Positioned(
                                  bottom: 0,
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: _warningColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
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
            ),
          ),

          // ================= 3. INFO SUB-BAR =================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Menampilkan $_total produk',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Urutan: Terbaru',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _outline,
                  ),
                ),
              ],
            ),
          ),

          // ================= 4. LIST STOK PRODUK =================
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: _outline),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textMuted)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: _muatAwal, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        color: _primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 52, color: const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    _hanyaMenipis
                        ? 'Tidak ada produk dengan stok menipis.'
                        : 'Belum ada produk. Tambahkan produk lebih dulu.',
                    style: const TextStyle(
                        color: _textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _muatAwal,
      color: _primary,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length + (_adaLagi ? 1 : 0) + 1, // +1 untuk tip banner
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          // Tip Banner di item paling akhir
          if (i == _items.length + (_adaLagi ? 1 : 0)) {
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: _primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ketuk kartu mana saja untuk mencatat penerimaan kontainer atau koreksi opname harian.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }

          final s = _items[i];
          return _buildStokCard(s);
        },
      ),
    );
  }

  // --- KARTU STOK PRODUK SESUAI TEMPLATE HTML ---
  Widget _buildStokCard(StokProduk s) {
    Color iconBg = const Color(0xFFD3E4FE);
    Color iconColor = _primary;
    Color countColor = _textDark;
    Color pillBg = const Color(0xFFDCE9FF);
    Color pillText = const Color(0xFF004AC6);
    String statusLabel = 'Aman';
    double progressRatio = 1.0;
    Color progressBarColor = _primary;

    if (s.habis) {
      iconBg = _errorBg;
      iconColor = _errorColor;
      countColor = _errorColor;
      pillBg = _errorBg;
      pillText = const Color(0xFF93000A);
      statusLabel = 'Habis';
      progressRatio = 0.0;
      progressBarColor = _errorColor;
    } else if (s.menipis) {
      iconBg = _warningBg;
      iconColor = _warningColor;
      countColor = _warningColor;
      pillBg = _warningBg;
      pillText = const Color(0xFF783200);
      statusLabel = 'Menipis';
      progressRatio = 0.4;
      progressBarColor = _warningBar;
    }

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _buka(s),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.inventory_2_rounded,
                          color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),

                    // Title & SKU
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nama,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${s.kode}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _outline,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stock Count & Unit + Chevron
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatAngka(s.jumlah),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: countColor,
                              ),
                            ),
                            Text(
                              s.satuan,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: Color(0xFFC3C6D7)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Middle Row: Stock Level Progress Bar
                Container(
                  width: double.infinity,
                  height: 6,
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

                // Bottom Row: Meta Info & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          s.habis
                              ? Icons.cancel_outlined
                              : (s.menipis
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline_rounded),
                          size: 15,
                          color: s.habis
                              ? _errorColor
                              : (s.menipis ? _warningColor : _outline),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Minimum ${formatAngka(s.stokMinimum)} ${s.satuan}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: s.habis || s.menipis
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: s.habis
                                ? _errorColor
                                : (s.menipis ? _warningColor : _outline),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}