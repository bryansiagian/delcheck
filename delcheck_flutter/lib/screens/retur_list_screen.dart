import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/retur.dart';
import '../providers/auth_provider.dart';
import '../services/retur_service.dart';
import '../widgets/retur_status_chip.dart';
import 'retur_buat_draft_screen.dart';
import 'retur_detail_screen.dart';

class _FilterRetur {
  const _FilterRetur(this.label, this.status, this.icon);

  final String label;
  final String? status;
  final IconData icon;
}

class ReturListScreen extends StatefulWidget {
  const ReturListScreen({super.key});

  @override
  State<ReturListScreen> createState() => _ReturListScreenState();
}

class _ReturListScreenState extends State<ReturListScreen> {
  static const _filtersUmum = <_FilterRetur>[
    _FilterRetur('Semua', null, Icons.all_inbox_rounded),
    _FilterRetur('Draft', Retur.statusDraft, Icons.edit_note_rounded),
    _FilterRetur('Diajukan', Retur.statusDiajukan, Icons.send_rounded),
    _FilterRetur('Ditolak', Retur.statusDitolak, Icons.cancel_outlined),
    _FilterRetur(
      'Disetujui',
      Retur.statusDisetujui,
      Icons.check_circle_outline,
    ),
    _FilterRetur('Dijadwalkan', Retur.statusDijadwalkan, Icons.event_outlined),
    _FilterRetur(
      'Dijemput',
      Retur.statusDijemput,
      Icons.local_shipping_outlined,
    ),
  ];

  static const _filtersSales = <_FilterRetur>[
    _FilterRetur('Semua', null, Icons.all_inbox_rounded),
    _FilterRetur('Diajukan', Retur.statusDiajukan, Icons.send_rounded),
    _FilterRetur(
      'Disetujui',
      Retur.statusDisetujui,
      Icons.check_circle_outline,
    ),
    _FilterRetur('Ditolak', Retur.statusDitolak, Icons.cancel_outlined),
    _FilterRetur('Dijadwalkan', Retur.statusDijadwalkan, Icons.event_outlined),
    _FilterRetur(
      'Dijemput',
      Retur.statusDijemput,
      Icons.local_shipping_outlined,
    ),
  ];

  final _scroll = ScrollController();
  final _cariCtrl = TextEditingController();
  final List<Retur> _items = [];
  late final ReturService _service;
  late final List<_FilterRetur> _filters;
  late final bool _sales;
  Timer? _debounce;
  late int _filterIndex;
  int _halaman = 0;
  int _halamanTerakhir = 1;
  int _total = 0;
  int _requestId = 0;
  String _q = '';
  bool _memuat = false;
  bool _memuatLagi = false;
  String? _error;

  bool get _adaLagi => _halaman < _halamanTerakhir;
  bool get _retail =>
      context.watch<AuthProvider?>()?.user?.punyaPeran('retail') ?? false;

  @override
  void initState() {
    super.initState();
    _service = ReturService(context.read<ApiClient>());
    _sales = context.read<AuthProvider?>()?.user?.punyaPeran('sales') ?? false;
    _filters = _sales ? _filtersSales : _filtersUmum;
    _filterIndex = _sales ? 1 : 0;
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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 220) {
      _muatLagi();
    }
  }

  Future<void> _muatAwal() async {
    final requestId = ++_requestId;
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final page = await _service.daftar(
        status: _filters[_filterIndex].status,
        q: _q,
        halaman: 1,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _halaman = page.halaman;
        _halamanTerakhir = page.halamanTerakhir;
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _items.clear();
          _error = e.message;
        });
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _memuat = false);
      }
    }
  }

  Future<void> _muatLagi() async {
    if (_memuat || _memuatLagi || !_adaLagi) return;
    final requestId = _requestId;
    setState(() => _memuatLagi = true);
    try {
      final page = await _service.daftar(
        status: _filters[_filterIndex].status,
        q: _q,
        halaman: _halaman + 1,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items.addAll(page.items);
        _halaman = page.halaman;
        _halamanTerakhir = page.halamanTerakhir;
      });
    } on ApiException catch (e) {
      if (mounted && requestId == _requestId) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _memuatLagi = false);
      }
    }
  }

  void _pilihFilter(int index) {
    if (index == _filterIndex) return;
    setState(() {
      _filterIndex = index;
      _items.clear();
    });
    _muatAwal();
  }

  void _cari(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = value.trim();
      if (query == _q) return;
      setState(() {
        _q = query;
        _items.clear();
      });
      _muatAwal();
    });
  }

  Future<void> _bukaDetail(Retur retur) async {
    final hasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ReturDetailScreen(returId: retur.id),
      ),
    );
    if (!mounted) return;
    await _muatAwal();
    if (mounted && hasil == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft Return berhasil dihapus.')),
      );
    }
  }

  Future<void> _buatReturn() async {
    final berhasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const ReturBuatDraftScreen()),
    );
    if (!mounted || berhasil != true) return;
    setState(() {
      _filterIndex = _filters.indexWhere(
        (filter) => filter.status == Retur.statusDraft,
      );
      _q = '';
      _cariCtrl.clear();
      _items.clear();
    });
    await _muatAwal();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft Return berhasil dibuat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final retail = _retail;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: retail
          ? FloatingActionButton.extended(
              onPressed: _buatReturn,
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Return'),
            )
          : null,
      body: Column(
        children: [
          _header(),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = index == _filterIndex;
                return ChoiceChip(
                  avatar: Icon(filter.icon, size: 17),
                  label: Text(filter.label),
                  selected: selected,
                  onSelected: (_) => _pilihFilter(index),
                  selectedColor: const Color(0xFFDBEAFE),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF1D4ED8) : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                  ),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menampilkan $_total Return',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(child: _konten()),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Kembali',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withAlpha(38),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daftar Return',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: _muatAwal,
                color: Colors.white,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cariCtrl,
            onChanged: (value) {
              setState(() {});
              _cari(value);
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nomor Return, toko, atau produk',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _cariCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _cariCtrl.clear();
                        setState(() {});
                        _cari('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _konten() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _PesanState(
        icon: Icons.cloud_off_rounded,
        judul: 'Daftar Return gagal dimuat',
        pesan: _error,
        aksi: FilledButton.icon(
          onPressed: _muatAwal,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 90),
            _PesanState(
              icon: Icons.inventory_2_outlined,
              judul: 'Belum ada Return',
              pesan: 'Return yang dapat Anda akses akan tampil di sini.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _muatAwal,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 6, 16, _retail ? 92 : 24),
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          return _kartu(_items[index]);
        },
      ),
    );
  }

  Widget _kartu(Retur retur) {
    final toko = retur.retailer?.namaToko ?? 'Toko';
    final produk =
        retur.item?.produk?.nama ?? retur.item?.namaProdukPesanan ?? 'Produk';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _bukaDetail(retur),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${retur.nomor}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: ReturStatusChip(retur: retur)),
                ],
              ),
              const SizedBox(height: 12),
              _baris(Icons.storefront_outlined, toko),
              const SizedBox(height: 7),
              _baris(
                Icons.inventory_2_outlined,
                '$produk · ${formatAngka(retur.item?.qty ?? 0)}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      retur.createdAt == null
                          ? 'Tanggal dibuat tidak tersedia'
                          : formatTanggalJam(retur.createdAt!),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baris(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 17, color: const Color(0xFF64748B)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
        ),
      ),
    ],
  );
}

class _PesanState extends StatelessWidget {
  const _PesanState({
    required this.icon,
    required this.judul,
    this.pesan,
    this.aksi,
  });

  final IconData icon;
  final String judul;
  final String? pesan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (pesan != null) ...[
            const SizedBox(height: 6),
            Text(
              pesan!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
          if (aksi != null) ...[const SizedBox(height: 16), aksi!],
        ],
      ),
    ),
  );
}
