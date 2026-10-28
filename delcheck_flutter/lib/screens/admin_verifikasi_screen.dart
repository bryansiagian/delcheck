import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
import '../services/admin_service.dart';
import 'admin_detail_retailer_screen.dart';

/// Daftar pendaftaran toko untuk diverifikasi admin.
class AdminVerifikasiScreen extends StatefulWidget {
  const AdminVerifikasiScreen({super.key});

  @override
  State<AdminVerifikasiScreen> createState() => _AdminVerifikasiScreenState();
}

class _AdminVerifikasiScreenState extends State<AdminVerifikasiScreen> {
  static const _statusList = {
    'menunggu': 'Menunggu',
    'disetujui': 'Disetujui',
    'ditolak': 'Ditolak',
  };

  late final AdminService _service;
  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  Timer? _debounce;

  final List<RetailerPendaftar> _items = [];
  String _status = 'menunggu';
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
    _service = AdminService(context.read<ApiClient>());
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
      final h = await _service.daftar(
          status: _status, q: _q, halaman: _halaman + 1);
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

  void _gantiStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
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

  Future<void> _buka(RetailerPendaftar item) async {
    final berubah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AdminDetailRetailerScreen(retailer: item)),
    );
    if (berubah == true && mounted) _muatAwal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Pendaftaran')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _cariCtrl,
              onChanged: _onCari,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama toko, kode, pemilik, telepon',
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
                for (final e in _statusList.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => _gantiStatus(e.key),
                  ),
              ],
            ),
          ),
          if (!_memuat && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total pendaftaran',
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
              ikon: Icons.inbox_outlined,
              teks: 'Tidak ada pendaftaran pada filter ini.',
            ),
          ],
        ),
      );
    }

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
          final r = _items[i];
          return Card(
            child: ListTile(
              onTap: () => _buka(r),
              leading: const CircleAvatar(child: Icon(Icons.storefront)),
              title: Text(r.namaToko,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  r.kode,
                  if (r.namaPemilik != null) r.namaPemilik!,
                  r.alamat,
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
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
