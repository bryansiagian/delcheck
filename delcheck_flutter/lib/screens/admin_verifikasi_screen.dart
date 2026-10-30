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
  static const _primary = Color(0xFF2563EB);
  static const _headerStart = Color(0xFF1D4ED8);
  static const _headerEnd = Color(0xFF3B82F6);
  static const _background = Color(0xFFF1F5F9);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

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
        builder: (_) => AdminDetailRetailerScreen(retailer: item),
      ),
    );
    if (berubah == true && mounted) _muatAwal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: _kolomPencarian(),
          ),
          _filterStatus(),
          if (!_memuat && _error == null) _ringkasanJumlah(),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 10,
      20,
      28,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_headerStart, _headerEnd],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -64,
          right: -42,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 26,
          left: 70,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Row(
          children: [
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Kembali',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Verifikasi Pendaftaran',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _kolomPencarian() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _textPrimary.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: _cariCtrl,
      onChanged: _onCari,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama toko, kode, pemilik, telepon',
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary),
        suffixIcon: _cariCtrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _cariCtrl.clear();
                  _onCari('');
                  setState(() {});
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    ),
  );

  Widget _filterStatus() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        for (final entry in _statusList.entries) ...[
          _filterChip(entry.key, entry.value),
          if (entry.key != _statusList.keys.last) const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _filterChip(String status, String label) {
    final selected = _status == status;
    final icon = switch (status) {
      'menunggu' => Icons.schedule_rounded,
      'disetujui' => Icons.check_circle_outline_rounded,
      _ => Icons.cancel_outlined,
    };
    return Material(
      color: selected ? _primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _gantiStatus(status),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _primary : _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringkasanJumlah() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Total Pendaftaran',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_total pendaftaran',
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _isi() {
    if (_memuat && _items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 14),
            Text(
              'Memuat pendaftaran...',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 50),
            _Pesan(
              ikon: Icons.cloud_off_outlined,
              judul: 'Gagal memuat pendaftaran',
              teks: _error!,
              aksi: FilledButton.icon(
                onPressed: _muatAwal,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 70),
            _Pesan(
              ikon: Icons.inbox_outlined,
              judul: 'Belum ada pendaftaran',
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _primary,
                  ),
                ),
              ),
            );
          }
          final r = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _kartuPendaftaran(r),
          );
        },
      ),
    );
  }

  Widget _kartuPendaftaran(RetailerPendaftar retailer) {
    final inisial = retailer.namaToko
        .trim()
        .split(RegExp(r'\s+'))
        .where((kata) => kata.isNotEmpty)
        .take(2)
        .map((kata) => kata.characters.first.toUpperCase())
        .join();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _buka(retailer),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: _textPrimary.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  inisial.isEmpty ? '?' : inisial,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      retailer.namaToko,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        retailer.kode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _metadataToko(
                      Icons.person_outline_rounded,
                      retailer.namaPemilik?.isNotEmpty == true
                          ? retailer.namaPemilik!
                          : '-',
                    ),
                    const SizedBox(height: 5),
                    _metadataToko(
                      Icons.location_on_outlined,
                      retailer.alamat.isNotEmpty ? retailer.alamat : '-',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadataToko(IconData ikon, String teks, {int maxLines = 1}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(ikon, size: 14, color: _textSecondary),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          teks,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}

class _Pesan extends StatelessWidget {
  const _Pesan({
    required this.ikon,
    required this.judul,
    required this.teks,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
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
            const SizedBox(height: 14),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AdminVerifikasiScreenState._textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              teks,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AdminVerifikasiScreenState._textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (aksi != null) ...[const SizedBox(height: 18), aksi!],
          ],
        ),
      ),
    );
  }
}
