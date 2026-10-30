import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/pengguna.dart';
import '../providers/auth_provider.dart';
import '../services/pengguna_service.dart';

class AdminPenggunaScreen extends StatefulWidget {
  const AdminPenggunaScreen({super.key});

  @override
  State<AdminPenggunaScreen> createState() => _AdminPenggunaScreenState();
}

class _AdminPenggunaScreenState extends State<AdminPenggunaScreen> {
  late final PenggunaService _service;
  late final int? _idSaya;

  final _cari = TextEditingController();
  final _scroll = ScrollController();

  static const _filterRole = <(String?, String)>[
    (null, 'Semua peran'),
    ('admin', 'Admin'),
    ('sales', 'Sales'),
    ('retail', 'Retail'),
    ('warehouse', 'Warehouse'),
  ];

  static const _filterStatus = <(bool?, String)>[
    (null, 'Semua status'),
    (true, 'Aktif'),
    (false, 'Nonaktif'),
  ];

  String? _role;
  bool? _aktif;

  List<Pengguna> _items = [];
  int _halaman = 1;
  int _terakhir = 1;
  int _total = 0;
  bool _memuat = true;
  bool _memuatLagi = false;
  String? _error;
  final Set<int> _diproses = {};

  @override
  void initState() {
    super.initState();
    // ApiClient bersama (membawa token admin). Jika di proyek Anda ApiClient
    // diambil dengan cara lain (lihat admin_verifikasi_screen.dart), samakan
    // baris di bawah ini.
    _service = PenggunaService(context.read<ApiClient>());
    _idSaya = context.read<AuthProvider>().user?.id;

    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _muatLagi();
      }
    });
    _muatAwal();
  }

  @override
  void dispose() {
    _cari.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _muatAwal() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final hasil = await _service.daftar(q: _cari.text, role: _role, aktif: _aktif);
      if (!mounted) return;
      setState(() {
        _items = hasil.items;
        _halaman = hasil.halaman;
        _terakhir = hasil.halamanTerakhir;
        _total = hasil.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _muatLagi() async {
    if (_memuat || _memuatLagi || _halaman >= _terakhir) return;
    setState(() => _memuatLagi = true);
    try {
      final hasil = await _service.daftar(
        q: _cari.text,
        role: _role,
        aktif: _aktif,
        page: _halaman + 1,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...hasil.items];
        _halaman = hasil.halaman;
        _terakhir = hasil.halamanTerakhir;
        _total = hasil.total;
      });
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  Future<void> _ubahStatus(Pengguna p, bool aktifkan) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aktifkan ? 'Aktifkan akun' : 'Nonaktifkan akun'),
        content: Text(aktifkan
            ? 'Aktifkan akun ${p.name}? Pengguna dapat login kembali.'
            : 'Nonaktifkan akun ${p.name}? Pengguna akan langsung keluar dari '
                'semua perangkat dan tidak bisa login sampai diaktifkan lagi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(aktifkan ? 'Aktifkan' : 'Nonaktifkan')),
        ],
      ),
    );
    if (setuju != true || !mounted) return;

    setState(() => _diproses.add(p.id));
    try {
      final hasil = aktifkan
          ? await _service.aktifkan(p.id)
          : await _service.nonaktifkan(p.id);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((e) => e.id == p.id);
        if (i < 0) return;
        // Jika sedang memfilter status, akun yang berubah status keluar dari daftar.
        if (_aktif != null && hasil.pengguna.isActive != _aktif) {
          _items.removeAt(i);
          if (_total > 0) _total--;
        } else {
          _items[i] = hasil.pengguna;
        }
      });
      _snack(hasil.pesan);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _diproses.remove(p.id));
    }
  }

  // ---------- UI ----------

  Widget _barisFilter<T>({
    required List<(T, String)> pilihan,
    required T terpilih,
    required ValueChanged<T> onPilih,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (nilai, label) in pilihan)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: terpilih == nilai,
                onSelected: (_) => onPilih(nilai),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(Pengguna p) {
    final saya = p.id == _idSaya;
    final sibuk = _diproses.contains(p.id);
    final terkunci = !p.isActive && p.tokoBelumDisetujui;
    final tema = Theme.of(context);

    final kontak = [
      if (p.email != null && p.email!.isNotEmpty) p.email!,
      if (p.phone != null && p.phone!.isNotEmpty) p.phone!,
    ].join(' • ');

    String? catatan;
    if (saya) {
      catatan = 'Akun Anda tidak dapat dinonaktifkan.';
    } else if (terkunci) {
      catatan = 'Toko belum disetujui: proses lewat menu Verifikasi Pendaftaran.';
    }

    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: p.isActive ? null : tema.colorScheme.surfaceContainerHighest,
          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
        ),
        title: Text(saya ? '${p.name} (Anda)' : p.name,
            style: p.isActive
                ? null
                : TextStyle(color: tema.colorScheme.onSurfaceVariant)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([
              p.peranLabel,
              if (p.namaToko != null) p.namaToko!,
            ].join(' • ')),
            if (kontak.isNotEmpty) Text(kontak),
            if (catatan != null)
              Text(catatan,
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ),
        trailing: sibuk
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: p.isActive,
                onChanged: (saya || terkunci) ? null : (v) => _ubahStatus(p, v),
              ),
      ),
    );
  }

  Widget _isi() {
    if (_memuat && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonal(
                onPressed: _muatAwal, child: const Text('Coba lagi')),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 48),
          Icon(Icons.people_outline, size: 48),
          SizedBox(height: 12),
          Text('Tidak ada pengguna.', textAlign: TextAlign.center),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _memuatLagi
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('$_total pengguna',
                      style: Theme.of(context).textTheme.bodySmall),
            ),
          );
        }
        return _item(_items[i]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pengguna')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _cari,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _muatAwal(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama, email, telepon, nama toko',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _cari.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _cari.clear();
                          _muatAwal();
                        },
                      ),
              ),
            ),
          ),
          _barisFilter<String?>(
            pilihan: _filterRole,
            terpilih: _role,
            onPilih: (v) {
              setState(() => _role = v);
              _muatAwal();
            },
          ),
          const SizedBox(height: 4),
          _barisFilter<bool?>(
            pilihan: _filterStatus,
            terpilih: _aktif,
            onPilih: (v) {
              setState(() => _aktif = v);
              _muatAwal();
            },
          ),
          Expanded(child: RefreshIndicator(onRefresh: _muatAwal, child: _isi())),
        ],
      ),
    );
  }
}
