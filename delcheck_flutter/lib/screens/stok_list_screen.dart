import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/stok.dart';
import '../services/stok_service.dart';
import 'stok_detail_screen.dart';

/// Daftar stok semua produk untuk Admin dan Warehouse.
class StokListScreen extends StatefulWidget {
  const StokListScreen({super.key});

  @override
  State<StokListScreen> createState() => _StokListScreenState();
}

class _StokListScreenState extends State<StokListScreen> {
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
  int _reqId = 0; // mencegah hasil permintaan lama menimpa yang baru

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    // Stok mungkin berubah di layar detail; muat ulang daftar.
    if (mounted) _muatAwal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok Produk')),
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
                hintText: 'Cari nama atau kode produk',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: !_hanyaMenipis,
                  onSelected: (_) => _gantiFilter(false),
                ),
                ChoiceChip(
                  label: const Text('Menipis / habis'),
                  selected: _hanyaMenipis,
                  onSelected: (_) => _gantiFilter(true),
                ),
              ],
            ),
          ),
          if (!_memuat && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total produk',
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
          children: [
            const SizedBox(height: 120),
            _Pesan(
              ikon: Icons.inventory_2_outlined,
              teks: _hanyaMenipis
                  ? 'Tidak ada produk dengan stok menipis.'
                  : 'Belum ada produk. Tambahkan produk lebih dulu.',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = _items[i];

          String? status;
          Color? warna;
          if (s.habis) {
            status = 'Habis';
            warna = tema.colorScheme.error;
          } else if (s.menipis) {
            status = 'Menipis (min ${formatAngka(s.stokMinimum)})';
            warna = Colors.orange.shade800;
          }

          return Card(
            child: ListTile(
              onTap: () => _buka(s),
              leading: const CircleAvatar(
                  child: Icon(Icons.inventory_2_outlined)),
              title: Text(s.nama,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.aktif ? s.kode : '${s.kode} • nonaktif'),
                  if (status != null)
                    Text(status,
                        style: TextStyle(
                            color: warna, fontWeight: FontWeight.w600)),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatAngka(s.jumlah),
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(s.satuan, style: tema.textTheme.bodySmall),
                ],
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
