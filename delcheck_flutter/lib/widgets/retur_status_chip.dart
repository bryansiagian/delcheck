import 'package:flutter/material.dart';

import '../models/retur.dart';

/// Chip status Return dengan warna yang konsisten untuk enam status backend.
class ReturStatusChip extends StatelessWidget {
  const ReturStatusChip({super.key, required this.retur});

  final Retur retur;

  @override
  Widget build(BuildContext context) {
    final (warna, label) = _style(retur.status, retur.statusLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: warna,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, String) _style(String status, String apiLabel) {
    switch (status) {
      case Retur.statusDraft:
        return (Colors.blueGrey.shade700, _label(apiLabel, 'Draft'));
      case Retur.statusDiajukan:
        return (Colors.orange.shade800, _label(apiLabel, 'Diajukan'));
      case Retur.statusDitolak:
        return (Colors.red.shade700, _label(apiLabel, 'Ditolak'));
      case Retur.statusDisetujui:
        return (Colors.green.shade700, _label(apiLabel, 'Disetujui'));
      case Retur.statusDijadwalkan:
        return (Colors.indigo.shade700, _label(apiLabel, 'Dijadwalkan'));
      case Retur.statusDijemput:
        return (Colors.teal.shade700, _label(apiLabel, 'Dijemput'));
      default:
        return (Colors.blueGrey.shade700, _label(apiLabel, status));
    }
  }

  String _label(String label, String fallback) =>
      label.trim().isEmpty ? fallback : label;
}
