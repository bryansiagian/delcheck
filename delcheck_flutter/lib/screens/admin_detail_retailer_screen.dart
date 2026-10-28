import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
import '../services/admin_service.dart';

/// Detail satu pendaftaran + aksi setujui / tolak (wajib alasan).
/// Menutup layar dengan `true` jika ada perubahan, supaya daftar dimuat ulang.
class AdminDetailRetailerScreen extends StatefulWidget {
  const AdminDetailRetailerScreen({super.key, required this.retailer});

  final RetailerPendaftar retailer;

  @override
  State<AdminDetailRetailerScreen> createState() =>
      _AdminDetailRetailerScreenState();
}

class _AdminDetailRetailerScreenState extends State<AdminDetailRetailerScreen> {
  late final AdminService _service;
  bool _bekerja = false;

  RetailerPendaftar get r => widget.retailer;

  @override
  void initState() {
    super.initState();
    _service = AdminService(context.read<ApiClient>());
  }

  Future<void> _setujui() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui pendaftaran?'),
        content: Text('${r.namaToko} akan diaktifkan dan dapat login.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Setujui')),
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
      // Sudah diproses admin lain: tutup dan muat ulang daftar.
      if (e.kode == 'PENDAFTARAN_SUDAH_DIPROSES') navigator.pop(true);
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  String _tgl(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pendaftaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                      radius: 26, child: Icon(Icons.storefront, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.namaToko,
                            style: tema.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(r.kode, style: tema.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(r.statusLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _Baris('Pemilik', r.namaPemilik),
                  _Baris('Telepon', r.telepon),
                  _Baris('Email', r.email),
                  _Baris('Alamat', r.alamat),
                  _Baris('Wilayah', r.wilayah),
                  _Baris('Mendaftar',
                      r.dibuat == null ? null : _tgl(r.dibuat!)),
                  if (r.alasanDitolak != null)
                    _Baris('Alasan ditolak', r.alasanDitolak),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: r.menunggu
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bekerja ? null : _tolak,
                        icon: const Icon(Icons.close),
                        label: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _bekerja ? null : _setujui,
                        icon: _bekerja
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: const Text('Setujui'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(nilai ?? '-')),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return AlertDialog(
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
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Alasan wajib diisi'
              : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
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
}
