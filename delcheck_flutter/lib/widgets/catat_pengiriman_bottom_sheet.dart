import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/pesanan.dart';

class CatatPengirimanBottomSheet extends StatefulWidget {
  const CatatPengirimanBottomSheet({
    super.key,
    required this.pesanan,
    required this.onSubmit,
  });

  final Pesanan pesanan;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  static Future<void> show({
    required BuildContext context,
    required Pesanan pesanan,
    required Future<void> Function(Map<String, dynamic> data) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CatatPengirimanBottomSheet(
        pesanan: pesanan,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<CatatPengirimanBottomSheet> createState() =>
      _CatatPengirimanBottomSheetState();
}

class _CatatPengirimanBottomSheetState
    extends State<CatatPengirimanBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _namaDriverCtrl = TextEditingController(text: 'Bambang Supriyadi');
  final _teleponDriverCtrl = TextEditingController(text: '081260449210');
  final _platCtrl = TextEditingController(text: 'BK 8392 GA');
  final _catatanCtrl = TextEditingController();

  bool _memuat = false;

  // Warna sesuai spesifikasi Tailwind HTML
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0B1C30);
  static const Color _textMuted = Color(0xFF4D556B);
  static const Color _inputBg = Color(0xFFF8F9FF);
  static const Color _cardBg = Color(0xFFE5EEFF);

  @override
  void dispose() {
    _namaDriverCtrl.dispose();
    _teleponDriverCtrl.dispose();
    _platCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _memuat = true);

    final nama = _namaDriverCtrl.text.trim();
    final telp = _teleponDriverCtrl.text.trim();
    final plat = _platCtrl.text.trim().toUpperCase();
    final note = _catatanCtrl.text.trim();

    // Menggabungkan keterangan agar tercatat lengkap di backend
    final catatanLengkap = [
      if (nama.isNotEmpty) 'Kurir: $nama',
      if (telp.isNotEmpty) 'Telp: $telp',
      if (plat.isNotEmpty) 'Plat: $plat',
      if (note.isNotEmpty) note,
    ].join(' | ');

    final payload = <String, dynamic>{
      'tanggal_kirim': tanggalApi(DateTime.now()),
      'nomor_surat_jalan': plat,
      'nama_pengemudi': nama,
      'telepon_pengemudi': telp,
      'nomor_kendaraan': plat,
      'catatan': catatanLengkap,
    };

    try {
      await widget.onSubmit(payload);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC3C6D7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catat Pengiriman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Pesanan #${widget.pesanan.nomor}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                            const Text(' • ',
                                style: TextStyle(
                                    color: _textMuted, fontSize: 12)),
                            Text(
                              widget.pesanan.tokoNama ?? 'Retail Store',
                              style: const TextStyle(
                                  fontSize: 12, color: _textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _cardBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          color: _primary, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Form Input: Nama Pengemudi
                _buildLabel('Nama pengemudi'),
                TextFormField(
                  controller: _namaDriverCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Masukkan nama pengemudi',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                // 4. Form Input: Telepon Pengemudi
                _buildLabel('Nomor telepon pengemudi'),
                TextFormField(
                  controller: _teleponDriverCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: '08xxxxxxxxxx',
                    icon: Icons.call_outlined,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nomor telepon wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),

                // 5. Form Input: Plat Kendaraan
                _buildLabel('Plat kendaraan'),
                TextFormField(
                  controller: _platCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Contoh: BK 1234 AB',
                    icon: Icons.directions_car_outlined,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Plat kendaraan wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),

                // 6. Form Input: Catatan Opsional
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLabel('Catatan (opsional)'),
                    const Text('Maks. 200 karakter',
                        style: TextStyle(fontSize: 11, color: Color(0xFF737686))),
                  ],
                ),
                TextFormField(
                  controller: _catatanCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hint: 'Catatan tambahan rute atau instruksi khusus',
                    icon: Icons.edit_note_rounded,
                    alignTop: true,
                  ),
                ),
                const SizedBox(height: 10),

                // 7. Quick Summary Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: _primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Status pengiriman akan otomatis berpindah ke Dalam Pengantaran.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 8. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _memuat ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: _memuat
                        ? const SizedBox()
                        : const Icon(Icons.local_shipping_rounded, size: 20),
                    label: _memuat
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Simpan dan serahkan ke kurir',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textMuted,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    bool alignTop = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _inputBg,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF737686), fontSize: 13),
      prefixIcon: Padding(
        padding: EdgeInsets.only(bottom: alignTop ? 38 : 0),
        child: Icon(icon, color: _textMuted, size: 20),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }
}