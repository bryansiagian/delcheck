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
  static const _primary = Color(0xFF2563EB);
  static const _headerStart = Color(0xFF1D4ED8);
  static const _headerEnd = Color(0xFF3B82F6);
  static const _background = Color(0xFFF1F5F9);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

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
      final hasil = await _service.daftar(
        q: _cari.text,
        role: _role,
        aktif: _aktif,
      );
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
        content: Text(
          aktifkan
              ? 'Aktifkan akun ${p.name}? Pengguna dapat login kembali.'
              : 'Nonaktifkan akun ${p.name}? Pengguna akan langsung keluar dari '
                    'semua perangkat dan tidak bisa login sampai diaktifkan lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aktifkan ? 'Aktifkan' : 'Nonaktifkan'),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (nilai, label) in pilihan)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: terpilih == nilai,
                onSelected: (_) => onPilih(nilai),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: terpilih == nilai ? Colors.white : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: _primary,
                backgroundColor: Colors.white,
                side: BorderSide(color: terpilih == nilai ? _primary : _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
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

    String? catatan;
    if (saya) {
      catatan = 'Akun Anda tidak dapat dinonaktifkan.';
    } else if (terkunci) {
      catatan =
          'Toko belum disetujui: proses lewat menu Verifikasi Pendaftaran.';
    }

    final inisial = p.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((kata) => kata.isNotEmpty)
        .take(2)
        .map((kata) => kata.characters.first.toUpperCase())
        .join();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _textPrimary.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.isActive
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      inisial.isEmpty ? '?' : inisial,
                      style: TextStyle(
                        color: p.isActive ? _primary : _textSecondary,
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 7,
                          runSpacing: 4,
                          children: [
                            Text(
                              p.name.isNotEmpty ? p.name : '-',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            if (saya)
                              _badge('Anda', const Color(0xFFDBEAFE), _primary),
                          ],
                        ),
                        const SizedBox(height: 5),
                        if (p.email?.isNotEmpty == true)
                          _metadata(Icons.email_outlined, p.email!),
                        if (p.phone?.isNotEmpty == true) ...[
                          if (p.email?.isNotEmpty == true)
                            const SizedBox(height: 3),
                          _metadata(Icons.phone_outlined, p.phone!),
                        ],
                        if ((p.email == null || p.email!.isEmpty) &&
                            (p.phone == null || p.phone!.isEmpty))
                          const Text(
                            '-',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (p.namaToko?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          _metadata(Icons.storefront_outlined, p.namaToko!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (p.roles.isEmpty)
                    _badge('-', const Color(0xFFF1F5F9), _textSecondary)
                  else
                    for (final role in p.roles) _badgeRole(role),
                  _badgeStatus(p.isActive),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: _border),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.isActive ? 'Akun aktif' : 'Akun nonaktif',
                          style: TextStyle(
                            color: p.isActive
                                ? const Color(0xFF16A34A)
                                : _textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (catatan != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            catatan,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (sibuk)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    )
                  else
                    Switch(
                      value: p.isActive,
                      onChanged: (saya || terkunci)
                          ? null
                          : (value) => _ubahStatus(p, value),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF16A34A),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadata(IconData icon, String value) => Row(
    children: [
      Icon(icon, size: 14, color: _textSecondary),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
      ),
    ],
  );

  Widget _badge(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _badgeRole(String role) {
    final (background, foreground) = switch (role.toLowerCase()) {
      'admin' => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      'sales' => (const Color(0xFFDBEAFE), _primary),
      'retail' => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
      'warehouse' => (const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      _ => (const Color(0xFFF1F5F9), _textSecondary),
    };
    final label = role.isEmpty
        ? '-'
        : '${role[0].toUpperCase()}${role.substring(1)}';
    return _badge(label, background, foreground);
  }

  Widget _badgeStatus(bool aktif) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        aktif ? Icons.check_circle_rounded : Icons.pause_circle_outline,
        size: 14,
        color: aktif ? const Color(0xFF16A34A) : _textSecondary,
      ),
      const SizedBox(width: 5),
      _badge(
        aktif ? 'Aktif' : 'Nonaktif',
        aktif ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        aktif ? const Color(0xFF16A34A) : _textSecondary,
      ),
    ],
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
              'Memuat akun...',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _pesanKosong(
              ikon: Icons.cloud_off_outlined,
              judul: 'Gagal memuat akun',
              deskripsi: _error!,
              aksi: FilledButton.icon(
                onPressed: _muatAwal,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      final mencari = _cari.text.trim().isNotEmpty;
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _pesanKosong(
              ikon: Icons.people_outline_rounded,
              judul: mencari ? 'Akun tidak ditemukan' : 'Belum ada akun',
              deskripsi: mencari
                  ? 'Coba kata kunci lain atau ubah filter yang dipilih.'
                  : 'Tidak ada pengguna pada filter ini.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _memuatLagi
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    )
                  : Text(
                      '$_total akun ditemukan',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
            ),
          );
        }
        return _item(_items[i]);
      },
    );
  }

  Widget _pesanKosong({
    required IconData ikon,
    required String judul,
    required String deskripsi,
    Widget? aksi,
  }) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(ikon, size: 34, color: _primary),
        ),
        const SizedBox(height: 16),
        Text(
          judul,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          deskripsi,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (aksi != null) ...[const SizedBox(height: 18), aksi],
      ],
    ),
  );

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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter peran',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter status akun',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _barisFilter<bool?>(
            pilihan: _filterStatus,
            terpilih: _aktif,
            onPilih: (v) {
              setState(() => _aktif = v);
              _muatAwal();
            },
          ),
          if (!_memuat && _error == null) _ringkasanJumlah(),
          Expanded(
            child: RefreshIndicator(
              color: _primary,
              onRefresh: _muatAwal,
              child: _isi(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 8,
      20,
      26,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_headerStart, _headerEnd],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -70,
          right: -44,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 34,
          left: 68,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelola Akun',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Kelola pengguna dan hak akses',
                    style: TextStyle(
                      color: Color(0xFFDCEAFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
      controller: _cari,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _muatAwal(),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Cari nama, email, telepon, atau nama toko',
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary),
        suffixIcon: _cari.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _cari.clear();
                  setState(() {});
                  _muatAwal();
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

  Widget _ringkasanJumlah() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Daftar pengguna',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_total akun ditemukan',
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
}
