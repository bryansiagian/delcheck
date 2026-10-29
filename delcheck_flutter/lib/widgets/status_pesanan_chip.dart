import 'package:flutter/material.dart';

import '../models/pesanan.dart';

/// Label status pesanan berwarna.
class StatusPesananChip extends StatelessWidget {
  const StatusPesananChip({super.key, required this.status});

  final String status;

  Color _warna(BuildContext context) {
    switch (status) {
      case 'menunggu_konfirmasi_sales':
      case 'diajukan':
        return Colors.orange.shade800;
      case 'dikonfirmasi':
        return Colors.blue.shade700;
      case 'diproses':
        return Colors.teal.shade700;
      case 'dikirim':
        return Colors.purple.shade600;
      case 'diterima':
      case 'selesai':
        return Colors.green.shade700;
      default: // ditolak, dibatalkan
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final warna = _warna(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        labelStatusPesanan(status),
        style:
            TextStyle(color: warna, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
