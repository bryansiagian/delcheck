import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../services/pesanan_service.dart';
import '../widgets/status_pesanan_chip.dart';
import 'buat_pesanan_screen.dart';
import 'pesanan_detail_screen.dart';

/// Satu pilihan filter status. [status] null = semua; boleh beberapa nilai
/// dipisah koma (mis. "dikonfirmasi,diproses").
class PesananFilter {
  const PesananFilter(this.label, this.status);

  final String label;
  final String? status;
}

/// Daftar pesanan. Dipakai Retail, Sales, dan Warehouse/Admin dengan filter berbeda.
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

  /// Tampilkan nama toko di tiap baris (untuk Sales dan Warehouse/Admin).
  final bool tampilkanToko;

  /// Tampilkan tombol "Pesan produk" (Retail).
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
  int _reqId = 0; // mencegah hasil permintaan lama menimpa yang baru

  bool _memuat = false;
  bool _memuatLagi = false;
  String? _error;

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    // Status mungkin berubah di layar detail; muat ulang daftar.
    if (mounted) _muatAwal();
  }

  Future<void> _pesanBaru() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuatPesananScreen()),
    );
    if (mounted) _muatAwal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.judul)),
      floatingActionButton: widget.bisaBuat
          ? FloatingActionButton.extended(
              onPressed: _pesanBaru,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Pesan produk'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _cariCtrl,
              onChanged: (v) {
                setState(() {}); // memperbarui tombol hapus teks
                _onCari(v);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.tampilkanToko
                    ? 'Cari nomor pesanan atau nama toko'
                    : 'Cari nomor pesanan',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _cariCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _cariCtrl.clear();
                          _onCari('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: widget.filter.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ChoiceChip(
                label: Text(widget.filter[i].label),
                selected: _filterIndex == i,
                onSelected: (_) => _gantiFilter(i),
              ),
            ),
          ),
          if (!_memuat && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total pesanan',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: _error!,
        aksi: FilledButton.tonal(
            onPressed: _muatAwal, child: const Text('Coba lagi')),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            _Pesan(
              ikon: Icons.receipt_long_outlined,
              teks: 'Belum ada pesanan pada filter ini.',
            ),
          ],
        ),
      );
    }

    final tema = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _muatAwal,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bisaBuat ? 96 : 24),
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = _items[i];
          final keterangan = [
            if (widget.tampilkanToko && p.tokoNama != null) p.tokoNama!,
            if (p.dibuat != null) formatTanggalJam(p.dibuat!),
            '${p.jumlahItem} item',
          ].join(' • ');

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _buka(p),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nomor,
                              style: tema.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(keterangan, style: tema.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRupiah(p.total),
                            style: tema.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        StatusPesananChip(status: p.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.aksi});

  final IconData ikon;
  final String teks;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(teks, textAlign: TextAlign.center),
            if (aksi != null) ...[const SizedBox(height: 16), aksi!],
          ],
        ),
      ),
    );
  }
}
