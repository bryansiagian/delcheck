import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../providers/auth_provider.dart';
import '../services/pesanan_service.dart';
import '../widgets/catat_pengiriman_bottom_sheet.dart';
import '../widgets/status_pesanan_chip.dart';

/// Detail pesanan modern sesuai desain HTML Tailwind
class PesananDetailScreen extends StatefulWidget {
  const PesananDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PesananDetailScreen> createState() => _PesananDetailScreenState();
}

class _PesananDetailScreenState extends State<PesananDetailScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF8F9FF);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF004AC6);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);
  static const Color _outline = Color(0xFF737686);

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

  Future<bool> _jalankan(
      Future<Pesanan> Function() aksi, String sukses) async {
    setState(() => _bekerja = true);
    try {
      final baru = await aksi();
      if (!mounted) return false;
      setState(() => _p = baru);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sukses)));
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tindakan gagal'),
          content: Text(e.message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup')),
          ],
        ),
      );
      if (mounted && e.kode == 'STATUS_PESANAN_TIDAK_VALID') _muat();
      return false;
    } finally {
      if (mounted) setState(() => _bekerja = false);
    }
  }

  Future<bool> _konfirmasi(String judul, String isi, String tombol) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(isi),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: _textMuted))),
          FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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

  // ---- Aksi Retail
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

  // ---- Aksi Sales
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

  // ---- Aksi Warehouse / Admin
  Future<void> _proses(Pesanan p) async {
    final ya = await _konfirmasi(
      'Barang sudah bersama kurir?',
      'Tandai pesanan ${p.nomor} sudah diserahkan ke kurir.',
      'Ya, bersama kurir',
    );
    if (!ya) return;
    await _jalankan(
      () => _service.tandaiJalan(p.id),
      'Pesanan diserahkan ke kurir.',
    );
  }

  Future<void> _kirim(Pesanan p) async {
    await CatatPengirimanBottomSheet.show(
      context: context,
      pesanan: p,
      onSubmit: (data) {
        return _jalankan(
          () => _service.catatPengiriman(p.id, data),
          'Pengiriman berhasil dicatat dan diserahkan ke kurir.',
        );
      },
    );
  }

  void _salinKode(String kode) {
    Clipboard.setData(ClipboardData(text: kode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Nomor pesanan disalin ke clipboard'),
          ],
        ),
      ),
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
            icon: const Icon(Icons.check_circle_outline),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(child: Row(children: tombol)),
    );
  }

  String _ambilInisial(String nama) {
    if (nama.trim().isEmpty) return 'TK';
    final parts = nama.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nama.substring(0, nama.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;

    return Scaffold(
      backgroundColor: _bgSurface,
      body: Column(
        children: [
          // ================= 1. HEADER BIRU LENGKUNG =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_primaryDark, _primary],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                ),
                const Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                InkWell(
                  onTap: p != null ? () => _salinKode(p.nomor) : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.content_copy_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ================= 2. ISI KONTEN =================
          Expanded(
            child: _memuat && p == null
                ? const Center(child: CircularProgressIndicator(color: _primary))
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
                                  onPressed: _muat,
                                  child: const Text('Coba lagi')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: _muat,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            // ================= CARD 1: RINGKASAN PESANAN (-mt-10) =================
                            Transform.translate(
                              offset: const Offset(0, -18),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Nomor pesanan',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: _outline,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              p.nomor,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        StatusPesananChip(status: p.status),
                                      ],
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(
                                          height: 1, color: Color(0xFFF1F5F9)),
                                    ),

                                    // Profil Toko
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD3E4FE),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _ambilInisial(p.tokoNama ?? 'TK'),
                                            style: const TextStyle(
                                              color: _primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.tokoNama ?? 'Toko Retail',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textDark,
                                                ),
                                              ),
                                              Text(
                                                p.tokoKode ?? 'Mitra Retail',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Meta info
                                    if (p.salesNama != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.person_pin_circle_outlined,
                                              size: 16, color: _outline),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Dikonfirmasi oleh ${p.salesNama}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: _textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (p.dibuat != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined,
                                              size: 15, color: _outline),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatTanggalJam(p.dibuat!),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: _textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Box Catatan
                                    if (p.catatan != null &&
                                        p.catatan!.trim().isNotEmpty) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF4FF),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.chat_bubble_outline_rounded,
                                                size: 16, color: _outline),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Catatan',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: _outline,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  Text(
                                                    p.catatan!,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _textDark),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Warning jika ditolak / batal
                                    if (p.alasanDitolak != null)
                                      _buildAlertBanner('Ditolak Sales: ${p.alasanDitolak}'),
                                    if (p.alasanBatal != null)
                                      _buildAlertBanner('Dibatalkan: ${p.alasanBatal}'),
                                  ],
                                ),
                              ),
                            ),

                            // ================= CARD 2: BARANG PESANAN =================
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Barang Pesanan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF4FF),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${p.items.length} barang',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _outline),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Daftar Barang
                                  for (int i = 0; i < p.items.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                          height: 20,
                                          color: Color(0xFFF1F5F9)),
                                    _buildItemRow(p.items[i]),
                                  ],
                                  const SizedBox(height: 16),

                                  // Total Box
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD3E4FE)
                                          .withOpacity(0.5),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: _textMuted),
                                        ),
                                        Text(
                                          formatRupiah(p.total),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: _primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ================= CARD 3: STATUS PENGIRIMAN =================
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status Pengiriman',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildTimelineStep(
                                    title: 'Siap dikirim',
                                    date: p.dikonfirmasiAt != null
                                        ? formatTanggalJam(p.dikonfirmasiAt!)
                                        : (p.dibuat != null
                                            ? formatTanggalJam(p.dibuat!)
                                            : null),
                                    icon: Icons.inventory_2_rounded,
                                    isDone: p.status != 'menunggu_konfirmasi_sales' &&
                                        p.status != 'ditolak' &&
                                        p.status != 'dibatalkan',
                                    isActive: p.status == 'dikonfirmasi',
                                    isLast: false,
                                  ),
                                  _buildTimelineStep(
                                    title: 'Bersama kurir',
                                    date: p.diprosesAt != null
                                        ? formatTanggalJam(p.diprosesAt!)
                                        : null,
                                    icon: Icons.person_pin_circle_rounded,
                                    isDone: p.status == 'diproses' ||
                                        p.status == 'dikirim' ||
                                        p.status == 'diterima' ||
                                        p.status == 'selesai',
                                    isActive: p.status == 'diproses',
                                    isLast: false,
                                  ),
                                  _buildTimelineStep(
                                    title: 'Dalam perjalanan',
                                    date: p.dikirimAt != null
                                        ? formatTanggalJam(p.dikirimAt!)
                                        : null,
                                    icon: Icons.local_shipping_rounded,
                                    isDone: p.status == 'dikirim' ||
                                        p.status == 'diterima' ||
                                        p.status == 'selesai',
                                    isActive: p.status == 'dikirim',
                                    isLast: false,
                                  ),
                                  _buildTimelineStep(
                                    title: 'Diterima',
                                    date: p.diterimaAt != null
                                        ? formatTanggalJam(p.diterimaAt!)
                                        : null,
                                    icon: Icons.check_circle_rounded,
                                    isDone: p.status == 'diterima' ||
                                        p.status == 'selesai',
                                    isActive: p.status == 'diterima' ||
                                        p.status == 'selesai',
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: p == null ? null : _aksiBar(p),
    );
  }

  Widget _buildItemRow(ItemPesanan item) {
    final satuanTampil =
        item.satuan.toLowerCase() == 'pak' ? 'pack' : item.satuan;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFD3E4FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.inventory_2_rounded,
              color: _primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.namaProduk,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatAngka(item.qty)} $satuanTampil × ${formatRupiah(item.harga)}',
                style: const TextStyle(fontSize: 12, color: _outline),
              ),
            ],
          ),
        ),
        Text(
          formatRupiah(item.subtotal),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String? date,
    required IconData icon,
    required bool isDone,
    required bool isActive,
    required bool isLast,
  }) {
    Color iconBg = const Color(0xFFEFF4FF);
    Color iconColor = const Color(0xFFC3C6D7);
    Color titleColor = _textMuted;
    Color subColor = _outline;

    if (isActive) {
      iconBg = const Color(0xFFFFDBCA);
      iconColor = const Color(0xFFF97316);
      titleColor = _textDark;
      subColor = _textMuted;
    } else if (isDone) {
      iconBg = const Color(0xFFD3E4FE);
      iconColor = _primary;
      titleColor = _textDark;
      subColor = _textMuted;
    }

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 15,
            top: 30,
            bottom: 0,
            child: Container(
              width: 2,
              color: const Color(0xFFF1F5F9),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: isActive
                      ? Border.all(color: const Color(0xFFFDBA74), width: 2)
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive || isDone ? FontWeight.bold : FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date ?? 'Belum tercapai',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner(String teks) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog alasan pembatalan / penolakan
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.judul,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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