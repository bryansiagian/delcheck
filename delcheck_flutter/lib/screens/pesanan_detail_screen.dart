import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/catat_pengiriman_bottom_sheet.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../providers/auth_provider.dart';
import '../services/pesanan_service.dart';
import '../widgets/status_pesanan_chip.dart';

/// Detail pesanan. Tombol aksi menyesuaikan peran dan status:
///  - Retail   : batalkan (menunggu), konfirmasi diterima (dalam perjalanan)
///  - Sales    : setujui / tolak (menunggu)
///  - Warehouse/Admin : bersama kurir / dalam perjalanan (dikonfirmasi, diproses)
class PesananDetailScreen extends StatefulWidget {
  const PesananDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PesananDetailScreen> createState() => _PesananDetailScreenState();
}

class _PesananDetailScreenState extends State<PesananDetailScreen> {
  late final PesananService _service;
  Pesanan? _p;
  bool _memuat = true;
  bool _bekerja = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = PesananService(context.read<ApiClient>());
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final p = await _service.detail(widget.id);
      if (mounted) setState(() => _p = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _jalankan(
      Future<Pesanan> Function() aksi, String sukses) async {
    setState(() => _bekerja = true);
    try {
      final baru = await aksi();
      if (!mounted) return;
      setState(() => _p = baru);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sukses)));
    } on ApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tindakan gagal'),
          content: Text(e.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup')),
          ],
        ),
      );
      // Status sudah berubah di sisi server: muat ulang tampilan.
      if (mounted && e.kode == 'STATUS_PESANAN_TIDAK_VALID') _muat();
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  Future<bool> _konfirmasi(String judul, String isi, String tombol) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tombol)),
        ],
      ),
    );
    return ya == true && mounted;
  }

  Future<String?> _mintaAlasan(String judul, String label) {
    return showDialog<String>(
      context: context,
      builder: (_) => _AlasanDialog(judul: judul, label: label),
    );
  }

  // ---- aksi Retail
  Future<void> _batalkan(Pesanan p) async {
    final alasan = await _mintaAlasan('Batalkan pesanan', 'Alasan pembatalan');
    if (alasan == null || !mounted) return;
    await _jalankan(() => _service.batalkan(p.id, alasan), 'Pesanan dibatalkan.');
  }

  Future<void> _terima(Pesanan p) async {
    final ya = await _konfirmasi(
      'Pesanan sudah diterima?',
      'Pastikan barang sudah sampai di toko Anda dan sesuai pesanan.',
      'Ya, sudah diterima',
    );
    if (!ya) return;
    await _jalankan(() => _service.terima(p.id), 'Pesanan dikonfirmasi diterima.');
  }

  // ---- aksi Sales
  Future<void> _setujui(Pesanan p) async {
    final ya = await _konfirmasi(
      'Setujui pesanan?',
      '${p.nomor} dari ${p.tokoNama ?? 'toko'} akan diteruskan ke gudang untuk dikirim.',
      'Setujui',
    );
    if (!ya) return;
    await _jalankan(() => _service.setujui(p.id), 'Pesanan disetujui.');
  }

  Future<void> _tolak(Pesanan p) async {
    final alasan = await _mintaAlasan('Tolak pesanan', 'Alasan penolakan');
    if (alasan == null || !mounted) return;
    await _jalankan(() => _service.tolak(p.id, alasan), 'Pesanan ditolak.');
  }

  // ---- aksi Warehouse / Admin
  Future<void> _proses(Pesanan p) async {
    final ya = await _konfirmasi(
      'Barang sudah bersama kurir?',
      'Tandai pesanan ${p.nomor} sudah diserahkan ke kurir. '
          'Stok belum berkurang sampai Anda menandai "Dalam perjalanan".',
      'Ya, bersama kurir',
    );
    if (!ya) return;
    await _jalankan(() => _service.proses(p.id), 'Pesanan diserahkan ke kurir.');
  }

  Future<void> _kirim(Pesanan p) async {
      await CatatPengirimanBottomSheet.show(
        context: context,
        pesanan: p,
        onSubmit: (data) async {
          await _jalankan(
            () => _service.kirim(p.id, data),
            'Pengiriman berhasil dicatat dan diserahkan ke kurir.',
          );
        },
      );
    }

  Widget? _aksiBar(Pesanan p) {
    final user = context.read<AuthProvider>().user;
    final retail = user?.punyaPeran('retail') ?? false;
    final sales = user?.punyaPeran('sales') ?? false;
    final gudang = (user?.punyaPeran('warehouse') ?? false) ||
        (user?.punyaPeran('admin') ?? false);

    final List<Widget> tombol;

    if (retail && p.menunggu) {
      tombol = [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _bekerja ? null : () => _batalkan(p),
            icon: const Icon(Icons.close),
            label: const Text('Batalkan pesanan'),
          ),
        ),
      ];
    } else if (retail && p.status == 'dikirim') {
      tombol = [
        Expanded(
          child: FilledButton.icon(
            onPressed: _bekerja ? null : () => _terima(p),
            icon: const Icon(Icons.inventory),
            label: const Text('Pesanan sudah diterima'),
          ),
        ),
      ];
    } else if (sales && p.menunggu) {
      tombol = [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _bekerja ? null : () => _tolak(p),
            icon: const Icon(Icons.close),
            label: const Text('Tolak'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _bekerja ? null : () => _setujui(p),
            icon: const Icon(Icons.check),
            label: const Text('Setujui'),
          ),
        ),
      ];
    } else if (gudang && p.status == 'dikonfirmasi') {
      tombol = [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _bekerja ? null : () => _proses(p),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Bersama kurir'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _bekerja ? null : () => _kirim(p),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Dalam perjalanan'),
          ),
        ),
      ];
    } else if (gudang && p.status == 'diproses') {
      tombol = [
        Expanded(
          child: FilledButton.icon(
            onPressed: _bekerja ? null : () => _kirim(p),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Dalam perjalanan'),
          ),
        ),
      ];
    } else {
      return null;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: tombol),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;

    return Scaffold(
      appBar: AppBar(title: Text(p?.nomor ?? 'Detail Pesanan')),
      body: _memuat && p == null
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Pesanan tidak ditemukan.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                            onPressed: _muat, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _muat,
                  child: _Isi(pesanan: p),
                ),
      bottomNavigationBar: p == null ? null : _aksiBar(p),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.pesanan});

  final Pesanan pesanan;

  @override
  Widget build(BuildContext context) {
    final p = pesanan;
    final tema = Theme.of(context);

    final linimasa = <MapEntry<String, DateTime?>>[
      MapEntry('Pesanan dibuat', p.dibuat),
      MapEntry(
          p.status == 'ditolak' ? 'Ditolak sales' : 'Dikonfirmasi sales',
          p.dikonfirmasiAt),
      MapEntry('Diserahkan ke kurir', p.diprosesAt),
      MapEntry('Dalam perjalanan', p.dikirimAt),
      MapEntry('Diterima toko', p.diterimaAt),
      MapEntry('Dibatalkan', p.dibatalkanAt),
    ].where((e) => e.value != null).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.tokoNama ?? 'Pesanan',
                          style: tema.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    StatusPesananChip(status: p.status),
                  ],
                ),
                if (p.tokoKode != null) ...[
                  const SizedBox(height: 2),
                  Text(p.tokoKode!, style: tema.textTheme.bodySmall),
                ],
                if (p.salesNama != null) ...[
                  const SizedBox(height: 8),
                  Text('Dikonfirmasi oleh ${p.salesNama}',
                      style: tema.textTheme.bodySmall),
                ],
                if (p.catatan != null) ...[
                  const SizedBox(height: 8),
                  Text('Catatan: ${p.catatan}'),
                ],
              ],
            ),
          ),
        ),

        if (p.alasanDitolak != null)
          _Peringatan(teks: 'Ditolak: ${p.alasanDitolak}'),
        if (p.alasanBatal != null)
          _Peringatan(teks: 'Dibatalkan: ${p.alasanBatal}'),

        // ---- barang
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text('Barang pesanan', style: tema.textTheme.titleSmall),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final item in p.items)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.namaProduk,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${formatAngka(item.qty)} ${item.satuan} × ${formatRupiah(item.harga)}',
                                  style: tema.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(formatRupiah(item.subtotal)),
                      ],
                    ),
                  ),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('Total',
                              style: tema.textTheme.titleSmall)),
                      Text(formatRupiah(p.total),
                          style: tema.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---- pengiriman
        if (p.pengiriman != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text('Pengiriman', style: tema.textTheme.titleSmall),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Baris('No. surat jalan / resi',
                      p.pengiriman!.nomorSuratJalan),
                  _Baris(
                      'Tanggal kirim',
                      p.pengiriman!.tanggalKirim == null
                          ? null
                          : formatTanggal(p.pengiriman!.tanggalKirim!)),
                  _Baris(
                      'Estimasi tiba',
                      p.pengiriman!.estimasiTiba == null
                          ? null
                          : formatTanggal(p.pengiriman!.estimasiTiba!)),
                  _Baris('Catatan', p.pengiriman!.catatan),
                ],
              ),
            ),
          ),
        ],

        // ---- linimasa
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text('Riwayat status', style: tema.textTheme.titleSmall),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final e in linimasa)
                  _Baris(e.key, formatTanggalJam(e.value!)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(teks,
          style: TextStyle(color: tema.colorScheme.onErrorContainer)),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris(this.label, this.nilai);

  final String label;
  final String? nilai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(nilai ?? '-')),
        ],
      ),
    );
  }
}

/// Dialog alasan (wajib diisi), untuk menolak dan membatalkan pesanan.
class _AlasanDialog extends StatefulWidget {
  const _AlasanDialog({required this.judul, required this.label});

  final String judul;
  final String label;

  @override
  State<_AlasanDialog> createState() => _AlasanDialogState();
}

class _AlasanDialogState extends State<_AlasanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Alasan wajib diisi' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _ctrl.text.trim());
            }
          },
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

/// Dialog catatan pengiriman. Kurir berada di luar sistem, jadi nama kurir
/// dicatat di kolom catatan dan resi di nomor surat jalan.
class _KirimDialog extends StatefulWidget {
  const _KirimDialog();

  @override
  State<_KirimDialog> createState() => _KirimDialogState();
}

class _KirimDialogState extends State<_KirimDialog> {
  final _suratCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  DateTime _tanggal = DateTime.now();
  DateTime? _estimasi;

  @override
  void dispose() {
    _suratCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final hariIni = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: hariIni.subtract(const Duration(days: 30)),
      lastDate: hariIni.add(const Duration(days: 30)),
    );
    if (d == null) return;
    setState(() {
      _tanggal = d;
      if (_estimasi != null && _estimasi!.isBefore(d)) _estimasi = null;
    });
  }

  Future<void> _pilihEstimasi() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _estimasi ?? _tanggal,
      firstDate: _tanggal,
      lastDate: _tanggal.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _estimasi = d);
  }

  String? _kosongJadiNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Barang dalam perjalanan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Stok produk akan berkurang sesuai jumlah pesanan.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _suratCtrl,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'No. surat jalan / resi (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pilihTanggal,
              icon: const Icon(Icons.event),
              label: Text('Tanggal kirim: ${formatTanggal(_tanggal)}'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pilihEstimasi,
                    icon: const Icon(Icons.event_available),
                    label: Text(_estimasi == null
                        ? 'Estimasi tiba (opsional)'
                        : 'Tiba: ${formatTanggal(_estimasi!)}'),
                  ),
                ),
                if (_estimasi != null)
                  IconButton(
                    tooltip: 'Hapus estimasi',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _estimasi = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan, mis. nama kurir (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, <String, dynamic>{
            'tanggal_kirim': tanggalApi(_tanggal),
            'estimasi_tiba': _estimasi == null ? null : tanggalApi(_estimasi!),
            'nomor_surat_jalan': _kosongJadiNull(_suratCtrl.text),
            'catatan': _kosongJadiNull(_catatanCtrl.text),
          }),
          child: const Text('Tandai dikirim'),
        ),
      ],
    );
  }
}
