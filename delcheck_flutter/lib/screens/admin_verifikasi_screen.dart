import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import 'admin_detail_retailer_screen.dart';

/// Daftar pendaftaran toko untuk diverifikasi Sales.
class AdminVerifikasiScreen extends StatefulWidget {
  const AdminVerifikasiScreen({super.key});

  @override
  State<AdminVerifikasiScreen> createState() => _AdminVerifikasiScreenState();
}

class _AdminVerifikasiScreenState extends State<AdminVerifikasiScreen> {
  static const _primary = Color(0xFF2563EB);
  static const _headerStart = Color(0xFF1D4ED8);
  static const _headerEnd = Color(0xFF3B82F6);
  static const _background = Color(0xFFF8F9FF);
  static const _textPrimary = Color(0xFF0B1C30);
  static const _textSecondary = Color(0xFF4D556B);
  static const _outline = Color(0xFF737686);

  static const _statusList = {
    'menunggu': 'Menunggu',
    'disetujui': 'Disetujui',
    'ditolak': 'Ditolak',
  };

  late final AdminService _service;
  late final bool _authorized;
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
    final user = context.read<AuthProvider>().user;
    _authorized =
        user?.punyaPeran('sales') == true && user?.punyaPeran('admin') != true;
    _scroll.addListener(_onScroll);
    if (_authorized) _muatAwal();
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
    if (!_authorized) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: const Text('Akses dibatasi')),
        body: const Center(
          child: Text('Halaman ini hanya dapat diakses oleh Sales.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _header(context),
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
      16,
      MediaQuery.paddingOf(context).top + 20,
      16,
      36,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_headerStart, _headerEnd],
      ),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x291D4ED8),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verifikasi Pendaftaran',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tinjau pendaftaran toko retail',
                    style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _kolomPencarian(),
      ],
    ),
  );

  Widget _kolomPencarian() => Container(
    height: 50,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TextField(
      controller: _cariCtrl,
      onChanged: _onCari,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama toko, kode, pemilik, telepon',
        hintStyle: const TextStyle(color: _outline, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _outline, size: 22),
        suffixIcon: _cariCtrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _cariCtrl.clear();
                  _onCari('');
                  setState(() {});
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _filterStatus() => Transform.translate(
    offset: const Offset(0, -22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final entry in _statusList.entries)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == _statusList.keys.last ? 0 : 4,
                  ),
                  child: _filterChip(entry.key, entry.value),
                ),
              ),
          ],
        ),
      ),
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
      color: selected ? const Color(0xFFE5EEFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _gantiStatus(status),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? _primary : _outline),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _primary : _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringkasanJumlah() => Transform.translate(
    offset: const Offset(0, -22),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Menampilkan $_total pendaftaran',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Status: ${_statusList[_status]}',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _outline,
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _buka(retailer),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                  color: const Color(0xFFD3E4FE),
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
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5EEFF),
                            borderRadius: BorderRadius.circular(10),
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
                        _badgeStatus(retailer),
                      ],
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
                  color: Color(0xFFC3C6D7),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeStatus(RetailerPendaftar retailer) {
    final (background, foreground, label) = switch (retailer.status) {
      'disetujui' => (
        const Color(0xFFCCFBF1),
        const Color(0xFF0D9488),
        'Disetujui',
      ),
      'ditolak' => (
        const Color(0xFFFFDAD6),
        const Color(0xFFBA1A1A),
        'Ditolak',
      ),
      _ => (const Color(0xFFFFDBCA), const Color(0xFF9D4300), 'Menunggu'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
            Icon(ikon, size: 48, color: const Color(0xFFCBD5E1)),
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
