import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';

/// Detail satu pendaftaran beserta aksi verifikasinya.
class AdminDetailRetailerScreen extends StatefulWidget {
  const AdminDetailRetailerScreen({super.key, required this.retailer});

  final RetailerPendaftar retailer;

  @override
  State<AdminDetailRetailerScreen> createState() =>
      _AdminDetailRetailerScreenState();
}

class _AdminDetailRetailerScreenState extends State<AdminDetailRetailerScreen> {
  static const _blue = Color(0xFF2563EB);
  static const _headerBlue = Color(0xFF004AC6);
  static const _background = Color(0xFFEFF4FF);
  static const _text = Color(0xFF0B1C30);
  static const _muted = Color(0xFF4D556B);
  static const _danger = Color(0xFFDC2626);
  static const _warning = Color(0xFF9D4300);
  static const _teal = Color(0xFF0D9488);

  late final AdminService _service;
  late RetailerPendaftar _retailer;
  bool _bekerja = false;

  RetailerPendaftar get r => _retailer;

  @override
  void initState() {
    super.initState();
    _retailer = widget.retailer;
    _service = AdminService(context.read<ApiClient>());
  }

  Future<void> _setujui() async {
    final ulang = r.ditolak;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ulang ? 'Setujui ulang pendaftaran?' : 'Setujui pendaftaran?',
        ),
        content: Text(
          ulang
              ? 'Pendaftaran ${r.namaToko} sebelumnya ditolak. Jika disetujui ulang, toko diaktifkan dan dapat login.'
              : '${r.namaToko} akan diaktifkan dan dapat login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ulang ? 'Setujui ulang' : 'Setujui'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    await _jalankan(() => _service.setujui(r.id));
  }

  Future<void> _tolak() async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => const _TolakDialog(),
    );
    if (alasan == null || !mounted) return;
    await _jalankan(() => _service.tolak(r.id, alasan));
  }

  Future<void> _jalankan(Future<String> Function() aksi) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _bekerja = true);
    try {
      final pesan = await aksi();
      messenger.showSnackBar(SnackBar(content: Text(pesan)));
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      // Jika petugas lain lebih dulu memproses pendaftaran, sinkronkan daftar.
      if (e.kode == 'PENDAFTARAN_SUDAH_DIPROSES') navigator.pop(true);
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  String _inisial(String nama) {
    final kata = nama.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (kata.isEmpty) return '?';
    return kata.take(2).map((e) => e.characters.first.toUpperCase()).join();
  }

  String _tanggal(DateTime? tanggal) {
    if (tanggal == null) return 'Tanggal pendaftaran tidak tersedia';
    final d = tanggal.toLocal();
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final jam = d.hour.toString().padLeft(2, '0');
    final menit = d.minute.toString().padLeft(2, '0');
    return 'Mendaftar ${d.day} ${bulan[d.month - 1]} ${d.year}, $jam.$menit';
  }

  String get _statusLabel => switch (r.status) {
    'menunggu' => 'Menunggu verifikasi',
    'disetujui' => 'Disetujui',
    'ditolak' => 'Ditolak',
    _ => r.statusLabel,
  };

  Color get _statusColor => switch (r.status) {
    'disetujui' => _teal,
    'ditolak' => const Color(0xFFBA1A1A),
    _ => _warning,
  };

  Color get _statusBackground => switch (r.status) {
    'disetujui' => const Color(0xFFCCFBF1),
    'ditolak' => const Color(0xFFFFDAD6),
    _ => const Color(0xFFFFDBCA),
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSales = user?.punyaPeran('sales') ?? false;
    final isAdmin = user?.punyaPeran('admin') ?? false;
    if (!isSales || isAdmin) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: const Text('Akses dibatasi')),
        body: const Center(
          child: Text('Halaman ini hanya dapat diakses oleh Sales.'),
        ),
      );
    }
    final showActions = isSales && !isAdmin && r.bisaDisetujui;

    return Scaffold(
      backgroundColor: _background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                _profilCard(),
                const SizedBox(height: 16),
                _isiDetail(),
                if (r.alasanDitolak != null && r.alasanDitolak!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _kartu(
                    title: 'Alasan penolakan',
                    children: [
                      _barisInfo(
                        Icons.info_outline_rounded,
                        'Catatan',
                        r.alasanDitolak!,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: showActions ? _actionBar() : null,
    );
  }

  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      MediaQuery.paddingOf(context).top + 20,
      16,
      20,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_headerBlue, _blue],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Color(0x29004AC6),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
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
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Detail Pendaftaran',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _profilCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFD3E4FE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _inisial(r.namaToko),
                style: const TextStyle(
                  color: _blue,
                  fontSize: 18,
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
                    r.namaToko,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.kode,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 15, color: _muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _tanggal(r.dibuat),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _isiDetail() {
    return Column(
      children: [
        _kartu(
          title: 'Informasi Toko',
          children: [
            _barisInfo(Icons.storefront_rounded, 'Nama toko', r.namaToko),
            _pemisah(),
            _barisInfo(Icons.location_on_outlined, 'Alamat', r.alamat),
            if (r.wilayah != null && r.wilayah!.isNotEmpty) ...[
              _pemisah(),
              _barisInfo(Icons.map_outlined, 'Wilayah', r.wilayah!),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _kartu(
          title: 'Informasi Pemilik',
          children: [
            _barisInfo(
              Icons.person_outline_rounded,
              'Nama pemilik',
              r.namaPemilik,
            ),
            _pemisah(),
            _barisInfo(Icons.phone_outlined, 'Nomor telepon', r.telepon),
            _pemisah(),
            _barisInfo(Icons.email_outlined, 'Email', r.email),
          ],
        ),
      ],
    );
  }

  Widget _kartu({required String title, required List<Widget> children}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _barisInfo(IconData icon, String label, String? value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFD3E4FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _blue, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 3),
              SelectableText(
                value?.trim().isNotEmpty == true ? value! : '-',
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _pemisah() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: Color(0xFFE5EEFF)),
  );

  Widget _actionBar() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (r.bisaDitolak) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _bekerja ? null : _tolak,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Tolak'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  side: const BorderSide(color: _danger, width: 1.5),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _bekerja ? null : _setujui,
              icon: _bekerja
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      r.ditolak ? Icons.restore_rounded : Icons.check_rounded,
                    ),
              label: Text(r.ditolak ? 'Setujui ulang' : 'Setujui'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                elevation: 2,
                shadowColor: _blue.withValues(alpha: 0.35),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dialog alasan penolakan (wajib diisi).
class _TolakDialog extends StatefulWidget {
  const _TolakDialog();

  @override
  State<_TolakDialog> createState() => _TolakDialogState();
}

class _TolakDialogState extends State<_TolakDialog> {
  final _formKey = GlobalKey<FormState>();
  final _alasanCtrl = TextEditingController();

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tolak pendaftaran'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _alasanCtrl,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Alasan penolakan',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Alasan wajib diisi' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _alasanCtrl.text.trim());
          }
        },
        child: const Text('Tolak'),
      ),
    ],
  );
}
