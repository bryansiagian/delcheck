import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/produk.dart';
import '../services/pesanan_service.dart';
import '../services/produk_service.dart';
import 'pesanan_detail_screen.dart';

/// Retail memilih produk dan jumlahnya, lalu mengirim pesanan (Modern UI)
class BuatPesananScreen extends StatefulWidget {
  const BuatPesananScreen({super.key});

  @override
  State<BuatPesananScreen> createState() => _BuatPesananScreenState();
}

class _BuatPesananScreenState extends State<BuatPesananScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF1F5F9);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  late final ProdukService _produkService;
  late final PesananService _pesananService;
  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  Timer? _debounce;

  final List<Produk> _items = [];
  final Map<int, Produk> _produk = {}; // cache produk
  final Map<int, int> _qty = {}; // produkId -> jumlah

  String _q = '';
  int _halaman = 0;
  int _halamanTerakhir = 1;
  int _reqId = 0;

  bool _memuat = false;
  bool _memuatLagi = false;
  bool _mengirim = false;
  String? _error;

  bool get _adaLagi => _halaman < _halamanTerakhir;
  int get _jumlahJenis => _qty.length;
  double get _total => _qty.entries
      .fold(0.0, (s, e) => s + (_produk[e.key]?.harga ?? 0) * e.value);

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _produkService = ProdukService(api);
    _pesananService = PesananService(api);
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

  void _simpanProduk(List<Produk> daftar) {
    for (final p in daftar) {
      _produk[p.id] = p;
    }
  }

  Future<void> _muatAwal() async {
    final id = ++_reqId;
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final h = await _produkService.daftar(q: _q, halaman: 1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(h.items);
        _simpanProduk(h.items);
        _halaman = h.halaman;
        _halamanTerakhir = h.halamanTerakhir;
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
      final h = await _produkService.daftar(q: _q, halaman: _halaman + 1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll(h.items);
        _simpanProduk(h.items);
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

  void _setQty(int produkId, int qty) {
    setState(() {
      if (qty <= 0) {
        _qty.remove(produkId);
      } else {
        _qty[produkId] = qty > 100000 ? 100000 : qty;
      }
    });
  }

  Future<void> _ketikQty(Produk p) async {
    final hasil = await showDialog<int>(
      context: context,
      builder: (_) => _QtyDialog(produk: p, awal: _qty[p.id] ?? 0),
    );
    if (hasil != null) _setQty(p.id, hasil);
  }

  Future<void> _tinjau() async {
    final baris = _qty.entries
        .where((e) => _produk[e.key] != null)
        .map((e) => _BarisKeranjang(_produk[e.key]!, e.value))
        .toList();
    if (baris.isEmpty) return;

    final catatan = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TinjauSheet(baris: baris, total: _total),
    );
    if (catatan == null || !mounted) return;

    setState(() => _mengirim = true);
    try {
      final p = await _pesananService.buat(
        items: [
          for (final b in baris) {'produk_id': b.produk.id, 'qty': b.qty},
        ],
        catatan: catatan.trim().isEmpty ? null : catatan.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan ${p.nomor} berhasil dikirim.')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PesananDetailScreen(id: p.id)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pesanan belum bisa dikirim',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(e.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: Column(
        children: [
          // ================= 1. HEADER BIRU GRADIENT (CURVED 32px) =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_primaryDark, Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                // Top Action Bar
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
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const Text(
                      'Pesan Produk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Cart Icon with Badge
                    InkWell(
                      onTap: _jumlahJenis > 0 ? _tinjau : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_outlined,
                                color: Colors.white, size: 22),
                            if (_jumlahJenis > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFD761A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$_jumlahJenis',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih produk untuk toko Anda',
                  style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Search Bar
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                      hintText: 'Cari nama atau kode produk',
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

          // ================= 2. META INFO ROW =================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_items.length} produk terdaftar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
                const Text(
                  'Retail DelCheck',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),

          // ================= 3. LIST PRODUK CARDS =================
          Expanded(child: _isi()),
        ],
      ),

      // ================= 4. FLOATING CART BAR =================
      bottomNavigationBar: _jumlahJenis == 0
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_jumlahJenis jenis produk dipilih',
                          style: const TextStyle(
                              fontSize: 11, color: _textMuted),
                        ),
                        Text(
                          formatRupiah(_total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _mengirim ? null : _tinjau,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: _mengirim
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Tinjau pesanan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
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
              const Icon(Icons.cloud_off_rounded, size: 48, color: _textMuted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: _muatAwal, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Produk tidak ditemukan.',
          style: TextStyle(color: _textMuted),
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16, 4, 16, _jumlahJenis > 0 ? 96 : 24),
      itemCount: _items.length + (_adaLagi ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        final p = _items[i];
        final qty = _qty[p.id] ?? 0;
        return _buildProdukCard(p, qty);
      },
    );
  }

  // --- KARTU PRODUK SESUAI TEMPLATE HTML ---
  Widget _buildProdukCard(Produk p, int qty) {
    // Otomatis ubah 'pak' menjadi 'pack'
    final satuanTampil = p.satuan.toLowerCase() == 'pak' ? 'pack' : p.satuan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Tile Icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: _primary, size: 26),
          ),
          const SizedBox(width: 14),

          // Detail Produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nama,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.sell_outlined,
                        size: 13, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(
                      p.kode,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: formatRupiah(p.harga),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                      TextSpan(
                        text: ' / $satuanTampil',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tersedia',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right Action Button (Tambah atau Stepper)
          if (qty == 0) ...[
            InkWell(
              onTap: () => _setQty(p.id, 1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _setQty(p.id, qty - 1),
                    icon: const Icon(Icons.remove, color: _primary),
                  ),
                  InkWell(
                    onTap: () => _ketikQty(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        formatAngka(qty),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _setQty(p.id, qty + 1),
                    icon: const Icon(Icons.add, color: _primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarisKeranjang {
  const _BarisKeranjang(this.produk, this.qty);

  final Produk produk;
  final int qty;
}

/// Dialog mengetik jumlah langsung
class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.produk, required this.awal});

  final Produk produk;
  final int awal;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.awal.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final satuan =
        widget.produk.satuan.toLowerCase() == 'pak' ? 'pack' : widget.produk.satuan;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.produk.nama,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Jumlah',
          suffixText: satuan,
          helperText: 'Isi 0 untuk menghapus dari pesanan',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v) ?? 0),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_ctrl.text.trim()) ?? 0),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Bottom Sheet Tinjau Pesanan Modern
class _TinjauSheet extends StatefulWidget {
  const _TinjauSheet({required this.baris, required this.total});

  final List<_BarisKeranjang> baris;
  final double total;

  @override
  State<_TinjauSheet> createState() => _TinjauSheetState();
}

class _TinjauSheetState extends State<_TinjauSheet> {
  final _catatanCtrl = TextEditingController();

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: tinggi,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFC3C6D7),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Tinjau Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final b in widget.baris) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.produk.nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${formatAngka(b.qty)} ${b.produk.satuan.toLowerCase() == "pak" ? "pack" : b.produk.satuan} × ${formatRupiah(b.produk.harga)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatRupiah(b.produk.harga * b.qty),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    Text(
                      formatRupiah(widget.total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _catatanCtrl,
                  maxLines: 2,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Catatan untuk pesanan (opsional)',
                    hintText: 'Contoh: Titipkan di toko samping bila tutup',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan akan diperiksa Sales sebelum diproses gudang.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _catatanCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Kirim pesanan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}