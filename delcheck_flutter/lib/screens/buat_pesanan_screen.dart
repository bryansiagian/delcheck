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

/// Retail memilih produk dan jumlahnya, lalu mengirim pesanan.
class BuatPesananScreen extends StatefulWidget {
  const BuatPesananScreen({super.key});

  @override
  State<BuatPesananScreen> createState() => _BuatPesananScreenState();
}

class _BuatPesananScreenState extends State<BuatPesananScreen> {
  late final ProdukService _produkService;
  late final PesananService _pesananService;
  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  Timer? _debounce;

  final List<Produk> _items = [];
  final Map<int, Produk> _produk = {}; // semua produk yang pernah tampil
  final Map<int, int> _qty = {}; // produkId -> jumlah (hanya yang > 0)

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
          SnackBar(content: Text('Pesanan ${p.nomor} terkirim.')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PesananDetailScreen(id: p.id)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pesanan belum bisa dikirim'),
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
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Produk')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _cariCtrl,
              onChanged: (v) {
                setState(() {});
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
          Expanded(child: _isi()),
        ],
      ),
      bottomNavigationBar: _jumlahJenis == 0
          ? null
          : Material(
              elevation: 8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_jumlahJenis produk dipilih',
                                style: tema.textTheme.bodySmall),
                            Text(formatRupiah(_total),
                                style: tema.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _mengirim ? null : _tinjau,
                        child: _mengirim
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Tinjau pesanan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _isi() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: _muatAwal, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Produk tidak ditemukan.'));
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length + (_adaLagi ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = _items[i];
        final qty = _qty[p.id] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nama,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${p.kode} • ${formatRupiah(p.harga)} / ${p.satuan}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (qty == 0)
                  FilledButton.tonal(
                    onPressed: () => _setQty(p.id, 1),
                    child: const Text('Tambah'),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _setQty(p.id, qty - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      InkWell(
                        onTap: () => _ketikQty(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Text(formatAngka(qty),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _setQty(p.id, qty + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BarisKeranjang {
  const _BarisKeranjang(this.produk, this.qty);

  final Produk produk;
  final int qty;
}

/// Dialog mengetik jumlah langsung. 0 = hapus dari pesanan.
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
    return AlertDialog(
      title: Text(widget.produk.nama),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Jumlah',
          suffixText: widget.produk.satuan,
          helperText: 'Isi 0 untuk menghapus dari pesanan',
          border: const OutlineInputBorder(),
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

/// Ringkasan pesanan + catatan. Menutup dengan catatan (String) jika dikirim.
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
    final tema = Theme.of(context);
    final tinggi = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: tinggi,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Tinjau pesanan', style: tema.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final b in widget.baris)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.produk.nama,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${formatAngka(b.qty)} ${b.produk.satuan} × ${formatRupiah(b.produk.harga)}',
                                    style: tema.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Text(formatRupiah(b.produk.harga * b.qty)),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                          child:
                              Text('Total', style: tema.textTheme.titleSmall)),
                      Text(formatRupiah(widget.total),
                          style: tema.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _catatanCtrl,
                    maxLines: 2,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Catatan untuk pesanan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Text(
                    'Pesanan akan diperiksa Sales sebelum diproses gudang.',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _catatanCtrl.text),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Kirim pesanan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
