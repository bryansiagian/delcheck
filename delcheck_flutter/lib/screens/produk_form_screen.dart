import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/produk.dart';
import '../services/produk_service.dart';

/// Form tambah / ubah produk. Menutup layar dengan `true` jika ada perubahan.
class ProdukFormScreen extends StatefulWidget {
  const ProdukFormScreen({super.key, this.produk});

  /// null = tambah produk baru, terisi = ubah produk.
  final Produk? produk;

  @override
  State<ProdukFormScreen> createState() => _ProdukFormScreenState();
}

class _ProdukFormScreenState extends State<ProdukFormScreen> {
  static const _satuanUmum = ['pcs', 'dus', 'pak', 'botol', 'kg', 'liter'];

  final _formKey = GlobalKey<FormState>();
  final _kodeCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _satuanCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _stokMinCtrl = TextEditingController(text: '0');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_edit ? 'Produk diperbarui.' : 'Produk ditambahkan.')));
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
        title: const Text('Hapus produk?'),
        content: Text('${widget.produk!.nama} akan dihapus dari katalog. '
            'Riwayat yang sudah ada tidak terpengaruh.\n\n'
            'Untuk menyembunyikan sementara, matikan saja "Produk aktif".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _bekerja = true);
    try {
      final pesan = await _service.hapus(widget.produk!.id);
      messenger.showSnackBar(SnackBar(content: Text(pesan)));
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_edit ? 'Ubah Produk' : 'Tambah Produk'),
        actions: [
          if (_edit)
            IconButton(
              tooltip: 'Hapus produk',
              icon: const Icon(Icons.delete_outline),
              onPressed: _bekerja ? null : _hapus,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: tema.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: tema.colorScheme.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _kodeCtrl,
                enabled: !_bekerja,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Kode produk',
                  helperText: 'Unik, tanpa spasi. Contoh: MIE-001',
                  border: const OutlineInputBorder(),
                  errorText: _fe('kode'),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Kode wajib diisi';
                  if (t.length > 40) return 'Kode maksimal 40 karakter';
                  if (!RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(t)) {
                    return 'Hanya huruf, angka, titik, strip, garis bawah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaCtrl,
                enabled: !_bekerja,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nama produk',
                  border: const OutlineInputBorder(),
                  errorText: _fe('nama'),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Nama wajib diisi';
                  if (t.length > 255) return 'Nama maksimal 255 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _satuanCtrl,
                enabled: !_bekerja,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Satuan',
                  border: const OutlineInputBorder(),
                  errorText: _fe('satuan'),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Satuan wajib diisi';
                  if (t.length > 20) return 'Satuan maksimal 20 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in _satuanUmum)
                    ActionChip(
                      label: Text(s),
                      onPressed: _bekerja
                          ? null
                          : () => setState(() => _satuanCtrl.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hargaCtrl,
                enabled: !_bekerja,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Harga',
                  prefixText: 'Rp ',
                  border: const OutlineInputBorder(),
                  errorText: _fe('harga'),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Harga wajib diisi';
                  if (double.tryParse(t) == null) return 'Harga tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stokMinCtrl,
                enabled: !_bekerja,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Stok minimum',
                  helperText: 'Peringatan muncul saat stok di bawah angka ini',
                  border: const OutlineInputBorder(),
                  errorText: _fe('stok_minimum'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deskripsiCtrl,
                enabled: !_bekerja,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: _fe('deskripsi'),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Produk aktif'),
                subtitle: const Text(
                    'Produk nonaktif tidak tampil untuk retail dan sales'),
                value: _aktif,
                onChanged: _bekerja ? null : (v) => setState(() => _aktif = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _bekerja ? null : _simpan,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _bekerja
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_edit ? 'Simpan perubahan' : 'Tambah produk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
