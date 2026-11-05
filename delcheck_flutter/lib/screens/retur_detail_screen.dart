import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/retur.dart';
import '../providers/auth_provider.dart';
import '../services/retur_service.dart';
import '../widgets/retur_status_chip.dart';
import '../widgets/retur_foto_image.dart';
import 'retur_buat_draft_screen.dart';

class ReturDetailScreen extends StatefulWidget {
  const ReturDetailScreen({super.key, required this.returId});

  final int returId;

  @override
  State<ReturDetailScreen> createState() => _ReturDetailScreenState();
}

class _ReturDetailScreenState extends State<ReturDetailScreen> {
  late final ReturService _service;
  Retur? _retur;
  String? _error;
  bool _memuat = true;
  bool _aksiBerjalan = false;
  final TextEditingController _alasanPenolakanController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = ReturService(context.read<ApiClient>());
    _muat();
  }

  @override
  void dispose() {
    _alasanPenolakanController.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final retur = await _service.detail(widget.returId);
      if (!mounted) return;
      setState(() => _retur = retur);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _editDraft() async {
    final berhasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ReturBuatDraftScreen(returId: widget.returId),
      ),
    );
    if (!mounted || berhasil != true) return;
    await _muat();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft Return berhasil diperbarui.')),
      );
    }
  }

  Future<void> _hapusDraft() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Draft Return?'),
        content: const Text('Draft yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Draft'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _aksiBerjalan = true);
    try {
      await _service.hapusDraft(widget.returId);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) _pesan(e.message);
    } catch (_) {
      if (mounted) _pesan('Draft Return gagal dihapus. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _aksiBerjalan = false);
    }
  }

  Future<void> _ajukanDraft() async {
    final retur = _retur;
    if (_aksiBerjalan || retur == null || !retur.isDraft) return;

    if (retur.alasan?.trim().isNotEmpty != true) {
      _pesan('Lengkapi alasan Return sebelum mengajukan.');
      return;
    }
    if (!['refund', 'replacement'].contains(retur.jenisPenyelesaian)) {
      _pesan('Pilih jenis penyelesaian sebelum mengajukan.');
      return;
    }
    if (retur.fotoKondisi.isEmpty) {
      _pesan('Unggah minimal satu foto kondisi produk sebelum mengajukan.');
      return;
    }

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan Return?'),
        content: const Text(
          'Pastikan alasan, jenis penyelesaian, dan foto kondisi produk sudah benar. Setelah diajukan, draft tidak dapat diedit atau dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajukan Return'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted || !_retur!.isDraft) return;

    setState(() => _aksiBerjalan = true);
    try {
      final hasil = await _service.ajukan(retur.id);
      if (!mounted) return;
      setState(() => _retur = hasil);
      _pesan('Return berhasil diajukan kepada Sales.');
    } on ApiException catch (e) {
      if (mounted) _pesan(e.message);
    } catch (_) {
      if (mounted) _pesan('Return gagal diajukan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _aksiBerjalan = false);
    }
  }

  Future<void> _setujuiPengajuan() async {
    final retur = _retur;
    if (_aksiBerjalan || retur == null || !retur.isDiajukan) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Return?'),
        content: const Text('Pengajuan Return ini akan disetujui.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted || !_retur!.isDiajukan) return;

    setState(() => _aksiBerjalan = true);
    try {
      final hasil = await _service.setujui(retur.id);
      if (!mounted) return;
      setState(() => _retur = hasil);
      _pesan('Return berhasil disetujui.');
    } on ApiException catch (e) {
      if (mounted) _pesan(e.message);
    } catch (_) {
      if (mounted) _pesan('Return gagal disetujui. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _aksiBerjalan = false);
    }
  }

  Future<void> _tolakPengajuan() async {
    final retur = _retur;
    if (_aksiBerjalan || retur == null || !retur.isDiajukan) return;

    _alasanPenolakanController.clear();
    String? error;
    final alasan = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tolak Return'),
          content: TextField(
            controller: _alasanPenolakanController,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Alasan penolakan',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty && error != null) {
                setDialogState(() => error = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () {
                final value = _alasanPenolakanController.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = 'Alasan penolakan wajib diisi.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Tolak'),
            ),
          ],
        ),
      ),
    );
    if (alasan == null || !mounted || !_retur!.isDiajukan) return;

    setState(() => _aksiBerjalan = true);
    try {
      final hasil = await _service.tolak(retur.id, alasan);
      if (!mounted) return;
      setState(() => _retur = hasil);
      _pesan('Return berhasil ditolak.');
    } on ApiException catch (e) {
      if (mounted) _pesan(e.message);
    } catch (_) {
      if (mounted) _pesan('Return gagal ditolak. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _aksiBerjalan = false);
    }
  }

  void _pesan(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final retur = _retur;
    final retail =
        context.watch<AuthProvider?>()?.user?.punyaPeran('retail') ?? false;
    final sales =
        context.watch<AuthProvider?>()?.user?.punyaPeran('sales') ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(retur == null ? 'Detail Return' : '#${retur.nomor}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _memuat && retur == null
          ? const Center(child: CircularProgressIndicator())
          : retur == null
          ? _gagal()
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _ringkasan(retur),
                  _section('Informasi pesanan', [
                    _baris('Nomor pesanan', retur.pesanan?.nomor),
                  ]),
                  _section('Retailer / toko', [
                    _baris('Nama toko', retur.retailer?.namaToko),
                    _baris('Kode toko', retur.retailer?.kode),
                  ]),
                  _section('Produk', [
                    _baris(
                      'Nama produk',
                      retur.item?.produk?.nama ?? retur.item?.namaProdukPesanan,
                    ),
                    _baris('Kode produk', retur.item?.produk?.kode),
                    _baris('Satuan', retur.item?.produk?.satuan),
                    _baris(
                      'Kuantitas Return',
                      retur.item == null ? null : formatAngka(retur.item!.qty),
                    ),
                  ]),
                  _section('Informasi Return', [
                    _baris('Alasan', retur.alasan),
                    _baris(
                      'Jenis penyelesaian',
                      _jenis(retur.jenisPenyelesaian),
                    ),
                    _baris('Dibuat', _tanggal(retur.createdAt)),
                    _baris(
                      retur.status == Retur.statusDitolak
                          ? 'Diputuskan'
                          : 'Dikonfirmasi',
                      _tanggal(retur.dikonfirmasiAt),
                    ),
                    _baris(
                      retur.status == Retur.statusDitolak
                          ? 'Diproses oleh'
                          : 'Dikonfirmasi oleh',
                      retur.dikonfirmasiOleh,
                    ),
                    _baris('Dijemput', _tanggal(retur.dijemputAt)),
                  ]),
                  if (retur.alasanDitolak?.isNotEmpty == true)
                    _peringatan(retur.alasanDitolak!),
                  if (retur.jadwalJemput != null ||
                      retur.catatanJemput?.isNotEmpty == true)
                    _section('Penjemputan', [
                      _baris('Jadwal', _tanggal(retur.jadwalJemput)),
                      _baris('Catatan', retur.catatanJemput),
                    ]),
                  _alur(retur),
                  if (retur.fotoKondisi.isNotEmpty)
                    _fotoSection('Foto kondisi produk', retur.fotoKondisi),
                  if (retur.fotoPenjemputan.isNotEmpty)
                    _fotoSection('Bukti penjemputan', retur.fotoPenjemputan),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: retail && retur?.isDraft == true
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _aksiBerjalan ? null : _hapusDraft,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _aksiBerjalan ? null : _editDraft,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Draft'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _aksiBerjalan ? null : _ajukanDraft,
                        icon: _aksiBerjalan
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _aksiBerjalan ? 'Mengajukan…' : 'Ajukan Return',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : sales && retur?.isDiajukan == true
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _aksiBerjalan ? null : _tolakPengajuan,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _aksiBerjalan ? null : _setujuiPengajuan,
                        icon: _aksiBerjalan
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_aksiBerjalan ? 'Memproses…' : 'Setujui'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _gagal() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 50,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Detail Return tidak ditemukan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _ringkasan(Retur retur) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${retur.nomor}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ReturStatusChip(retur: retur),
            ],
          ),
          if (retur.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Dibuat ${formatTanggalJam(retur.createdAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _section(String title, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    ),
  );

  Widget _baris(String label, String? value) {
    final shown = value?.trim();
    if (shown == null || shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shown,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peringatan(String alasan) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFB91C1C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Alasan penolakan: $alasan',
            style: const TextStyle(color: Color(0xFF991B1B)),
          ),
        ),
      ],
    ),
  );

  Widget _alur(Retur retur) {
    const steps = [
      ('draft', 'Draft'),
      ('diajukan', 'Diajukan'),
      ('disetujui', 'Disetujui'),
      ('dijadwalkan', 'Dijadwalkan'),
      ('dijemput', 'Dijemput'),
    ];
    final current = retur.status == Retur.statusDitolak
        ? 1
        : steps.indexWhere((step) => step.$1 == retur.status);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alur status',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < steps.length; i++)
                _langkah(steps[i].$2, i <= current, i == current),
              if (retur.status == Retur.statusDitolak)
                _langkah('Ditolak', true, true, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langkah(
    String label,
    bool selesai,
    bool aktif, {
    bool danger = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          danger
              ? Icons.cancel_rounded
              : selesai
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 19,
          color: danger
              ? const Color(0xFFDC2626)
              : selesai
              ? const Color(0xFF2563EB)
              : const Color(0xFFCBD5E1),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: danger
                ? const Color(0xFFB91C1C)
                : aktif
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF64748B),
            fontWeight: aktif || danger ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _fotoSection(String title, List<ReturFoto> fotos) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 360 ? 1 : 2;
                final width =
                    (constraints.maxWidth - 10 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final foto in fotos)
                      SizedBox(
                        width: width,
                        child: ReturFotoImage(
                          key: ValueKey(foto.id),
                          service: _service,
                          foto: foto,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  String? _tanggal(DateTime? value) =>
      value == null ? null : formatTanggalJam(value);

  String? _jenis(String? value) {
    if (value == null || value.isEmpty) return null;
    return switch (value.toLowerCase()) {
      'refund' => 'Refund',
      'replacement' => 'Replacement',
      _ => value,
    };
  }
}
