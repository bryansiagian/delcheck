import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../services/pesanan_service.dart';
import 'buat_pesanan_screen.dart';
import 'pesanan_detail_screen.dart';

/// Satu pilihan filter status
class PesananFilter {
  const PesananFilter(this.label, this.status, {this.icon = Icons.layers});

  final String label;
  final String? status;
  final IconData icon;
}

/// Layar Daftar Pengiriman & Pesanan Modern
class PesananListScreen extends StatefulWidget {
  const PesananListScreen({
    super.key,
    required this.judul,
    required this.filter,
    this.tampilkanToko = false,
    this.bisaBuat = false,
  });

  final String judul;
  final List<PesananFilter> filter;
  final bool tampilkanToko;
  final bool bisaBuat;

  @override
  State<PesananListScreen> createState() => _PesananListScreenState();
}

class _PesananListScreenState extends State<PesananListScreen> {
  late final PesananService _service;
  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  Timer? _debounce;

  final List<Pesanan> _items = [];
  int _filterIndex = 0;
  String _q = '';
  int _halaman = 0;
  int _halamanTerakhir = 1;
  int _total = 0;
  int _reqId = 0;

  bool _memuat = false;
  bool _memuatLagi = false;
  String? _error;

  // Warna sesuai spesifikasi Tailwind
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  bool get _adaLagi => _halaman < _halamanTerakhir;
  String? get _status => widget.filter[_filterIndex].status;

  @override
  void initState() {
    super.initState();
    _service = PesananService(context.read<ApiClient>());
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
      final h = await _service.daftar(status: _status, q: _q, halaman: 1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
        _total = h.total;
      });
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
      final h =
          await _service.daftar(status: _status, q: _q, halaman: _halaman + 1);
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

  void _gantiFilter(int index) {
    if (index == _filterIndex) return;
    setState(() {
      _filterIndex = index;
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

  Future<void> _buka(Pesanan p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PesananDetailScreen(id: p.id)),
    );
    if (mounted) _muatAwal();
  }

  Future<void> _pesanBaru() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuatPesananScreen()),
    );
    if (mounted) _muatAwal();
  }

  String _ambilInisial(String nama) {
    if (nama.trim().isEmpty) return 'TK';
    final parts = nama.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nama.substring(0, nama.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      floatingActionButton: widget.bisaBuat
          ? FloatingActionButton.extended(
              onPressed: _pesanBaru,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Pesan produk'),
            )
          : null,
      body: Column(
        children: [
          // ================= 1. HEADER BIRU GRADIENT =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 38),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.judul,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Pantau dan catat pengiriman pesanan',
                          style: TextStyle(
                            color: Color(0xFFDBEAFE),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Input
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                      hintText: 'Cari nomor pesanan atau nama toko',
                      hintStyle:
                          const TextStyle(color: _textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: _textMuted, size: 22),
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

          // ================= 2. STATUS FILTER HORIZONTAL =================
          Transform.translate(
            offset: const Offset(0, -24),
            child: SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.filter.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final item = widget.filter[i];
                  final isAktif = _filterIndex == i;

                  // Tentukan warna filter card
                  Color iconBg = const Color(0xFFDBEAFE);
                  Color iconColor = _primary;

                  if (item.label.toLowerCase().contains('siap')) {
                    iconBg = const Color(0xFFFFEDD5);
                    iconColor = const Color(0xFFF97316);
                  } else if (item.label.toLowerCase().contains('kurir')) {
                    iconBg = const Color(0xFFE0E7FF);
                    iconColor = const Color(0xFF4F46E5);
                  } else if (item.label.toLowerCase().contains('jalan')) {
                    iconBg = const Color(0xFFDBEAFE);
                    iconColor = _primary;
                  } else if (item.label.toLowerCase().contains('terima')) {
                    iconBg = const Color(0xFFCCFBF1);
                    iconColor = const Color(0xFF0D9488);
                  }

                  return InkWell(
                    onTap: () => _gantiFilter(i),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAktif ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAktif ? _primary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon, color: iconColor, size: 20),
                          ),
                          Column(
                            children: [
                              Text(
                                isAktif ? '$_total' : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isAktif ? _primary : _textDark,
                                ),
                              ),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isAktif
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isAktif ? _primary : _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ================= 3. INFO ROW =================
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menampilkan $_total pengiriman',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
            ),
          ),

          // ================= 4. LIST PENGIRIMAN =================
          Expanded(child: _isiKonten()),
        ],
      ),
    );
  }

  Widget _isiKonten() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: _textMuted),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _muatAwal, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        color: _primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 54, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'Tidak ada pengiriman pada filter ini',
                    style: TextStyle(
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
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          final p = _items[i];
          return _buildPengirimanCard(p);
        },
      ),
    );
  }

  // --- KARTU PENGIRIMAN SESUAI DESAIN HTML ---
  Widget _buildPengirimanCard(Pesanan p) {
    final statusNorm = p.status.toLowerCase();

    // Status Styling Data
    Color statusBg = const Color(0xFFFFEDD5);
    Color statusColor = const Color(0xFFF97316);
    IconData statusIcon = Icons.inventory_2_rounded;
    String statusText = 'Siap dikirim';
    int stepActive = 1; // 1: Siap, 2: Kurir, 3: Jalan, 4: Diterima

    if (statusNorm == 'diproses') {
      statusBg = const Color(0xFFE0E7FF);
      statusColor = const Color(0xFF4F46E5);
      statusIcon = Icons.person_pin_circle_rounded;
      statusText = 'Bersama kurir';
      stepActive = 2;
    } else if (statusNorm == 'dikirim') {
      statusBg = const Color(0xFFDBEAFE);
      statusColor = _primary;
      statusIcon = Icons.local_shipping_rounded;
      statusText = 'Dalam perjalanan';
      stepActive = 3;
    } else if (statusNorm == 'diterima' || statusNorm == 'selesai') {
      statusBg = const Color(0xFFCCFBF1);
      statusColor = const Color(0xFF0D9488);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Diterima';
      stepActive = 4;
    }

    final namaToko = p.tokoNama ?? 'Retail Store';
    final inisial = _ambilInisial(namaToko);

    return Container(
      padding: const EdgeInsets.all(16),
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
          // 1. Top Row: Nomor & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${p.nomor}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.dibuat != null ? formatTanggalJam(p.dibuat!) : '',
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Store Row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  inisial,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaToko,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const Text(
                      'Wilayah Pengiriman Retail',
                      style: TextStyle(fontSize: 11, color: _textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Meta Row (Items & Total Rupiah)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 15, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${p.jumlahItem} item',
                      style: const TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 15, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(
                      formatRupiah(p.total),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. Mini Progress Tracker 4 Tahap
          _buildProgressTracker(stepActive, statusColor),
          const SizedBox(height: 14),

          // 5. Tombol Aksi Sesuai Status
          if (stepActive == 1) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _buka(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text(
                  'Catat pengiriman',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else if (stepActive == 2 || stepActive == 3) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _buka(p),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.sync_rounded, size: 20),
                label: const Text(
                  'Perbarui status',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF0D9488), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pengiriman Telah Selesai Diterima',
                    style: TextStyle(
                      color: Color(0xFF0D9488),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Mini Progress Tracker ---
  Widget _buildProgressTracker(int activeStep, Color themeColor) {
    const steps = ['Siap', 'Kurir', 'Jalan', 'Diterima'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Garis penghubung
          final stepIndex = (index ~/ 2) + 1;
          final isLineActive = stepIndex < activeStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isLineActive ? themeColor : const Color(0xFFE2E8F0),
            ),
          );
        } else {
          // Lingkaran step
          final stepIndex = (index ~/ 2) + 1;
          final isStepPassed = stepIndex <= activeStep;

          return Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isStepPassed ? themeColor : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isStepPassed
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                steps[index ~/ 2],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isStepPassed ? FontWeight.bold : FontWeight.w500,
                  color: isStepPassed ? themeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}