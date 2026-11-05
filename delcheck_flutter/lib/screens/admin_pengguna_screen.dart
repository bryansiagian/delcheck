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
  static const _background = Color(0xFFF8F9FF);
  static const _textPrimary = Color(0xFF0B1C30);
  static const _textSecondary = Color(0xFF4D556B);
  static const _outline = Color(0xFF737686);
  static const _border = Color(0xFFE5EEFF);

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
      padding: EdgeInsets.zero,
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
                  color: terpilih == nilai ? _primary : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: const Color(0xFFE5EEFF),
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
          'Toko belum disetujui: periksa status melalui menu Verifikasi Pendaftaran.';
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
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
                          ? const Color(0xFFD3E4FE)
                          : const Color(0xFFE5EEFF),
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
                              _badge('Anda', const Color(0xFFD3E4FE), _primary),
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
                    _badge('-', const Color(0xFFE5EEFF), _textSecondary)
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
                                ? const Color(0xFF0D9488)
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
                      activeTrackColor: const Color(0xFF0D9488),
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
      'admin' => (const Color(0xFFDCE9FF), const Color(0xFF004AC6)),
      'sales' => (const Color(0xFFE5EEFF), _primary),
      'retail' => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
      'warehouse' => (const Color(0xFFFFDBCA), const Color(0xFF9D4300)),
      _ => (const Color(0xFFE5EEFF), _textSecondary),
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
        color: aktif ? const Color(0xFF0D9488) : const Color(0xFFBA1A1A),
      ),
      const SizedBox(width: 5),
      _badge(
        aktif ? 'Aktif' : 'Nonaktif',
        aktif ? const Color(0xFFCCFBF1) : const Color(0xFFFFDAD6),
        aktif ? const Color(0xFF0D9488) : const Color(0xFFBA1A1A),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
        Icon(ikon, size: 52, color: const Color(0xFFCBD5E1)),
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
          _panelFilter(),
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
                    'Kelola Akun',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Kelola pengguna dan hak akses',
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
                Icons.manage_accounts_rounded,
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
      controller: _cari,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _muatAwal(),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Cari nama, email, telepon, atau nama toko',
        hintStyle: const TextStyle(color: _outline, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _outline, size: 22),
        suffixIcon: _cari.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _cari.clear();
                  setState(() {});
                  _muatAwal();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _panelFilter() => Transform.translate(
    offset: const Offset(0, -22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 2, 8, 5),
              child: Text(
                'Peran',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _barisFilter<String?>(
              pilihan: _filterRole,
              terpilih: _role,
              onPilih: (value) {
                setState(() => _role = value);
                _muatAwal();
              },
            ),
            const Divider(height: 16, color: _border),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 5),
              child: Text(
                'Status akun',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _barisFilter<bool?>(
              pilihan: _filterStatus,
              terpilih: _aktif,
              onPilih: (value) {
                setState(() => _aktif = value);
                _muatAwal();
              },
            ),
          ],
        ),
      ),
    ),
  );

  Widget _ringkasanJumlah() => Transform.translate(
    offset: const Offset(0, -22),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
          Text(
            'Menampilkan $_total pengguna',
            style: const TextStyle(
              fontSize: 12,
              color: _outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
