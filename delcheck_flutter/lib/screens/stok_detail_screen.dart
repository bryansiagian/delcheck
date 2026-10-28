import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/stok.dart';
import '../services/stok_service.dart';

/// Detail stok satu produk: tambah / kurangi stok dan lihat riwayatnya.
class StokDetailScreen extends StatefulWidget {
  const StokDetailScreen({super.key, required this.stok});

  final StokProduk stok;

  @override
  State<StokDetailScreen> createState() => _StokDetailScreenState();
}

class _StokDetailScreenState extends State<StokDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController();
  final _alasanCtrl = TextEditingController();

  late final StokService _service;
  late StokProduk _stok;

  bool _tambah = true; // true = tambah stok, false = kurangi
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
        _jumlahCtrl.clear();
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
    final tema = Theme.of(context);

    final Color warnaStatus;
    final String teksStatus;
    if (_stok.habis) {
      warnaStatus = tema.colorScheme.error;
      teksStatus = 'Stok habis';
    } else if (_stok.menipis) {
      warnaStatus = Colors.orange.shade800;
      teksStatus = 'Stok menipis (minimum ${formatAngka(_stok.stokMinimum)})';
    } else {
      warnaStatus = tema.colorScheme.primary;
      teksStatus = 'Stok aman (minimum ${formatAngka(_stok.stokMinimum)})';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Produk')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- ringkasan stok
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_stok.nama,
                        style: tema.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_stok.kode, style: tema.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatAngka(_stok.jumlah),
                            style: tema.textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(_stok.satuan,
                              style: tema.textTheme.titleMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(teksStatus,
                        style: TextStyle(
                            color: warnaStatus, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ---- form tambah / kurangi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: true,
                              icon: Icon(Icons.add),
                              label: Text('Tambah')),
                          ButtonSegment(
                              value: false,
                              icon: Icon(Icons.remove),
                              label: Text('Kurangi')),
                        ],
                        selected: {_tambah},
                        onSelectionChanged: _bekerja
                            ? null
                            : (s) => setState(() {
                                  _tambah = s.first;
                                  _fieldErrors = {};
                                  _error = null;
                                }),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null && _fieldErrors.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: tema.colorScheme.onErrorContainer)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _jumlahCtrl,
                        enabled: !_bekerja,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: _tambah
                              ? 'Jumlah ditambah'
                              : 'Jumlah dikurangi',
                          suffixText: _stok.satuan,
                          border: const OutlineInputBorder(),
                          errorText: _fe('jumlah'),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 1) {
                            return 'Isi jumlah minimal 1';
                          }
                          if (!_tambah && n > _stok.jumlah) {
                            return 'Melebihi stok saat ini '
                                '(${formatAngka(_stok.jumlah)})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _alasanCtrl,
                        enabled: !_bekerja,
                        maxLength: 255,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText:
                              _tambah ? 'Catatan (opsional)' : 'Alasan',
                          helperText: _tambah
                              ? 'Contoh: barang datang dari pemasok'
                              : 'Wajib. Contoh: barang rusak, salah hitung',
                          border: const OutlineInputBorder(),
                          errorText: _fe('alasan'),
                        ),
                        validator: (v) {
                          if (!_tambah && (v ?? '').trim().isEmpty) {
                            return 'Alasan wajib diisi saat mengurangi stok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _bekerja ? null : _simpan,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: _bekerja
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_tambah ? Icons.add : Icons.remove),
                        label:
                            Text(_tambah ? 'Tambah stok' : 'Kurangi stok'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- riwayat
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('Riwayat stok', style: tema.textTheme.titleMedium),
            ),
            if (_errorRiwayat != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(_errorRiwayat!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                        onPressed: _muatRiwayat,
                        child: const Text('Coba lagi')),
                  ],
                ),
              )
            else if (_memuatRiwayat && _riwayat.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_riwayat.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Belum ada riwayat stok.')),
              )
            else ...[
              for (final m in _riwayat) _BarisRiwayat(m: m, satuan: _stok.satuan),
              if (_halaman < _halamanTerakhir)
                Center(
                  child: TextButton(
                    onPressed: _memuatRiwayat
                        ? null
                        : () => _muatRiwayat(lagi: true),
                    child: _memuatRiwayat
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Muat lebih banyak'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.m, required this.satuan});

  final MutasiStok m;
  final String satuan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = m.masuk ? Colors.green.shade700 : tema.colorScheme.error;
    final tanda = m.masuk ? '+' : '-';

    final keterangan = [
      if (m.alasan != null) m.alasan!,
      if (m.oleh != null) 'oleh ${m.oleh}',
      if (m.dibuat != null) formatTanggalJam(m.dibuat!),
    ].join(' • ');

    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(m.masuk ? Icons.arrow_downward : Icons.arrow_upward,
            color: warna),
        title: Text('$tanda${formatAngka(m.jumlah.abs())} $satuan',
            style: TextStyle(color: warna, fontWeight: FontWeight.bold)),
        subtitle: keterangan.isEmpty ? null : Text(keterangan),
        trailing: Text(
            '${formatAngka(m.stokSebelum)} → ${formatAngka(m.stokSesudah)}',
            style: tema.textTheme.bodySmall),
      ),
    );
  }
}
