import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
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
  static const _headerBlue = Color(0xFF1D4ED8);
  static const _secondaryBlue = Color(0xFF3B82F6);
  static const _background = Color(0xFFF1F5F9);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _danger = Color(0xFFDC2626);

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
      // Jika admin lain lebih dulu memproses pendaftaran, sinkronkan daftar.
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
    'disetujui' => const Color(0xFF16A34A),
    'ditolak' => _danger,
    _ => const Color(0xFFF97316),
  };

  Color get _statusBackground => switch (r.status) {
    'disetujui' => const Color(0xFFDCFCE7),
    'ditolak' => const Color(0xFFFEE2E2),
    _ => const Color(0xFFFFEDD5),
  };

  @override
  Widget build(BuildContext context) {
    final showActions = r.bisaDisetujui;

    return Scaffold(
      backgroundColor: _background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _profilCard(),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _isiDetail(),
            ),
          ),
          if (r.alasanDitolak != null && r.alasanDitolak!.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _kartu(
                  title: 'Alasan penolakan',
                  children: [
                    _barisInfo(
                      Icons.info_outline_rounded,
                      'Catatan',
                      r.alasanDitolak!,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: showActions ? _actionBar() : null,
    );
  }

  
  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 10,
      20,
      76,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _headerBlue,
          _secondaryBlue,
        ],
      ),
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(32),
      ),
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Lingkaran dekorasi kanan atas
        Positioned(
          top: -70,
          right: -48,
          child: Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Lingkaran dekorasi kiri
        Positioned(
          top: 36,
          left: 28,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Tombol kembali dan judul
        Row(
          children: [
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Kembali',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Detail Pendaftaran',
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


  Widget _profilCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _inisial(r.namaToko),
            style: const TextStyle(
              color: _blue,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          r.namaToko,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusBackground,
            borderRadius: BorderRadius.circular(30),
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
              const SizedBox(width: 7),
              Text(
                _statusLabel,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tanggal(r.dibuat),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
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
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
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
          color: const Color(0xFFDBEAFE),
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
    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                  minimumSize: const Size(0, 52),
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
                elevation: 4,
                shadowColor: _blue.withValues(alpha: 0.35),
                minimumSize: const Size(0, 52),
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
