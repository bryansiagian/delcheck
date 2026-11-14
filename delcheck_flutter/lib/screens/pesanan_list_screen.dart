import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/catat_pengiriman_bottom_sheet.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../providers/auth_provider.dart';
import '../services/pesanan_service.dart';
import '../widgets/status_pesanan_chip.dart';
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
    this.tampilanRetail = false,
    this.tampilanSales = false,
    this.tampilanWarehouse = false,
  });

  final String judul;
  final List<PesananFilter> filter;
  final bool tampilkanToko;
  final bool bisaBuat;
  final bool tampilanRetail;
  final bool tampilanSales;
  final bool tampilanWarehouse;

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

  // Menyimpan hitungan untuk seluruh tab sekaligus
  final Map<int, int> _countsPerFilter = {};

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
    _muatSemuaHitungan();
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

  /// Menghitung angka untuk setiap tab filter di latar belakang
  void _muatSemuaHitungan() {
    for (int i = 0; i < widget.filter.length; i++) {
      final f = widget.filter[i];
      _service.daftar(status: f.status, q: _q, halaman: 1).then((res) {
        if (mounted) {
          setState(() {
            _countsPerFilter[i] = res.total;
          });
        }
      }).catchError((_) {});
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
        _countsPerFilter[_filterIndex] = h.total;
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
      final h = await _service.daftar(
        status: _status,
        q: _q,
        halaman: _halaman + 1,
      );
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      _muatSemuaHitungan();
    });
  }

  Future<void> _buka(Pesanan p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PesananDetailScreen(id: p.id)),
    );
    if (mounted) {
      _muatAwal();
      _muatSemuaHitungan();
    }
  }

  Future<void> _pesanBaru() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuatPesananScreen()),
    );
    if (mounted) {
      _muatAwal();
      _muatSemuaHitungan();
    }
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
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
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
                        Text(
                          widget.tampilanSales
                              ? 'Tinjau pesanan Retail yang menunggu keputusan'
                              : widget.tampilanRetail
                              ? 'Pantau pesanan dan riwayat transaksi'
                              : 'Pantau dan catat pengiriman pesanan',
                          style: const TextStyle(
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
                      hintText: widget.tampilanRetail
                          ? 'Cari nomor pesanan'
                          : 'Cari nomor pesanan atau nama toko',
                      hintStyle: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _textMuted,
                        size: 22,
                      ),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

                  if (item.label.toLowerCase().contains('siap') ||
                      item.label.toLowerCase().contains('proses') ||
                      item.label.toLowerCase().contains('diproses')) {
                    iconBg = const Color(0xFFFFEDD5);
                    iconColor = const Color(0xFFF97316);
                  } else if (item.label.toLowerCase().contains('kurir') ||
                      item.label.toLowerCase().contains('setuju') ||
                      item.label.toLowerCase().contains('disetujui')) {
                    iconBg = const Color(0xFFE0E7FF);
                    iconColor = const Color(0xFF4F46E5);
                  } else if (item.label.toLowerCase().contains('jalan')) {
                    iconBg = const Color(0xFFDBEAFE);
                    iconColor = _primary;
                  } else if (item.label.toLowerCase().contains('terima')) {
                    iconBg = const Color(0xFFCCFBF1);
                    iconColor = const Color(0xFF0D9488);
                  }

                  // Mengambil jumlah secara bersamaan untuk semua tab
                  final jumlah = _countsPerFilter[i]?.toString() ??
                      (isAktif ? '$_total' : '0');

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
                                jumlah, // <-- Menampilkan angka tanpa harus ditekan
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
                'Menampilkan $_total ${widget.bisaBuat ? "pesanan" : "pengiriman"}',
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
              onPressed: () {
                _muatAwal();
                _muatSemuaHitungan();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _muatAwal();
          _muatSemuaHitungan();
        },
        color: _primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox_rounded,
                    size: 54,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.tampilanSales
                        ? 'Tidak ada pesanan yang menunggu konfirmasi'
                        : widget.tampilanRetail
                        ? 'Tidak ada pesanan pada kategori ini'
                        : 'Tidak ada pengiriman pada filter ini',
                    style: TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _muatAwal();
        _muatSemuaHitungan();
      },
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
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          final p = _items[i];
          return widget.tampilanRetail ||
                  widget.tampilanSales ||
                  widget.tampilanWarehouse
              ? _buildKartuPesanan(p)
              : _buildPengirimanCard(p);
        },
      ),
    );
  }

  Widget _buildKartuPesanan(Pesanan p) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _buka(p),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${p.nomor}',
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.dibuat == null
                              ? 'Tanggal tidak tersedia'
                              : formatTanggalJam(p.dibuat!),
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (widget.tampilanSales && p.tokoNama != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            p.tokoNama!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPesananChip(status: p.status),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 17,
                    color: _textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${p.jumlahItem} item',
                    style: const TextStyle(color: _textMuted, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    formatRupiah(p.total),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lihat detail  ›',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- KARTU PENGIRIMAN SESUAI DESAIN HTML ---
  Widget _buildPengirimanCard(Pesanan p) {
    final statusNorm = p.status.toLowerCase();

    Color statusBg = const Color(0xFFF1F5F9);
    Color statusColor = const Color(0xFF475569);
    IconData statusIcon = Icons.info_outline_rounded;
    String statusText = p.statusLabel;
    String statusInfo = 'Status pesanan: ${p.statusLabel}.';
    int? stepActive;

    switch (statusNorm) {
      case 'menunggu_konfirmasi_sales':
        statusBg = const Color(0xFFFFEDD5);
        statusColor = const Color(0xFFC2410C);
        statusIcon = Icons.hourglass_top_rounded;
        statusText = 'Menunggu konfirmasi Sales';
        statusInfo =
            'Pesanan ini belum dapat diproses untuk pengiriman. Silakan menunggu konfirmasi dari Sales.';
        break;
      case 'ditolak':
        statusBg = const Color(0xFFFEE2E2);
        statusColor = const Color(0xFFB91C1C);
        statusIcon = Icons.cancel_outlined;
        statusText = 'Ditolak oleh Sales';
        statusInfo = 'Pesanan ditolak oleh Sales dan tidak dapat dikirim.';
        break;
      case 'dibatalkan':
        statusBg = const Color(0xFFF1F5F9);
        statusColor = const Color(0xFF64748B);
        statusIcon = Icons.block_outlined;
        statusText = 'Pesanan dibatalkan';
        statusInfo = 'Pesanan dibatalkan dan tidak dapat dikirim.';
        break;
      case 'dikonfirmasi':
        statusBg = const Color(0xFFFFEDD5);
        statusColor = const Color(0xFFF97316);
        statusIcon = Icons.inventory_2_rounded;
        statusText = 'Siap dikirim';
        statusInfo = 'Pesanan telah dikonfirmasi Sales dan siap dikirim.';
        stepActive = 1;
        break;
      case 'diproses':
        statusBg = const Color(0xFFE0E7FF);
        statusColor = const Color(0xFF4F46E5);
        statusIcon = Icons.person_pin_circle_rounded;
        statusText = p.pengiriman?.status == 'kurir'
            ? 'Kurir'
            : 'Pengiriman belum dicatat';
        statusInfo = p.pengiriman?.status == 'kurir'
            ? 'Pengiriman sudah dicatat dan stok telah diperbarui.'
            : 'Pesanan ini belum memiliki data pengiriman.';
        if (p.pengiriman?.status == 'kurir') stepActive = 2;
        break;
      case 'dikirim':
        statusBg = const Color(0xFFDBEAFE);
        statusColor = _primary;
        statusIcon = Icons.local_shipping_rounded;
        statusText = p.pengiriman?.status == 'jalan'
            ? 'Dalam perjalanan'
            : 'Status pengiriman perlu diperiksa';
        statusInfo = p.pengiriman?.status == 'jalan'
            ? 'Kurir telah berangkat dan pesanan sedang dikirim.'
            : 'Status pesanan dan pengiriman tidak sesuai.';
        if (p.pengiriman?.status == 'jalan') stepActive = 3;
        break;
      case 'diterima':
      case 'selesai':
        statusBg = const Color(0xFFCCFBF1);
        statusColor = const Color(0xFF0D9488);
        statusIcon = Icons.check_circle_rounded;
        statusText = p.pengiriman?.status == 'diterima'
            ? 'Diterima'
            : 'Status pengiriman perlu diperiksa';
        statusInfo = p.pengiriman?.status == 'diterima'
            ? 'Pesanan telah diterima.'
            : 'Status pesanan dan pengiriman tidak sesuai.';
        if (p.pengiriman?.status == 'diterima') stepActive = 4;
        break;
    }

    final isAdmin =
        context.read<AuthProvider>().user?.punyaPeran('admin') ?? false;
    final bisaCatatPengiriman =
        isAdmin && statusNorm == 'dikonfirmasi' && p.pengiriman == null;
    final bisaTandaiJalan =
        isAdmin && statusNorm == 'diproses' && p.pengiriman?.status == 'kurir';

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
          // 1. Top Row: Nomor & Status Chip (Responsif untuk layar HP)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${p.nomor}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _textDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p.dibuat != null ? formatTanggalJam(p.dibuat!) : '',
                                style: const TextStyle(fontSize: 11, color: _textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: _textMuted,
                    ),
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
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 15,
                      color: _textMuted,
                    ),
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

          if (stepActive != null) ...[
            // 4. Mini Progress Tracker 4 Tahap
            _buildProgressTracker(stepActive, statusColor),
            const SizedBox(height: 14),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusInfo,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5. Tombol Aksi Sesuai Status
          if (bisaCatatPengiriman || bisaTandaiJalan) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: bisaCatatPengiriman
                    ? () {
                        CatatPengirimanBottomSheet.show(
                          context: context,
                          pesanan: p,
                          onSubmit: (data) async {
                            try {
                              await _service.catatPengiriman(p.id, data);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Pengiriman dicatat dan stok diperbarui.',
                                    ),
                                  ),
                                );
                                _muatAwal();
                                _muatSemuaHitungan();
                              }
                              return true;
                            } on ApiException catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                              }
                              return false;
                            }
                          },
                        );
                      }
                    : () => _tandaiJalan(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  bisaCatatPengiriman
                      ? Icons.edit_note_rounded
                      : Icons.local_shipping_outlined,
                  size: 20,
                ),
                label: Text(
                  bisaCatatPengiriman ? 'Catat Pengiriman' : 'Tandai Jalan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _buka(p),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Lihat detail pesanan'),
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
                  fontWeight: isStepPassed ? FontWeight.bold : FontWeight.w500,
                  color: isStepPassed ? themeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Future<void> _tandaiJalan(Pesanan pesanan) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Jalan?'),
        content: const Text(
          'Pastikan kurir sudah mengabarkan bahwa pesanan telah berangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tandai Jalan'),
          ),
        ],
      ),
    );
    if (setuju != true || !mounted) return;

    try {
      await _service.tandaiJalan(pesanan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan ditandai sedang dalam perjalanan.'),
        ),
      );
      await _muatAwal();
      _muatSemuaHitungan();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}