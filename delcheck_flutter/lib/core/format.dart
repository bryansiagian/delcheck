/// Angka dengan pemisah ribuan, mis. 95000 -> "95.000".
String formatAngka(num nilai) {
  final bulat = nilai.round();
  final digit = bulat.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) buf.write('.');
    buf.write(digit[i]);
  }
  final tanda = bulat < 0 ? '-' : '';
  return '$tanda$buf';
}

/// Format angka menjadi rupiah, mis. 95000 -> "Rp 95.000".
String formatRupiah(num nilai) {
  return nilai < 0
      ? '-Rp ${formatAngka(nilai.abs())}'
      : 'Rp ${formatAngka(nilai)}';
}

/// Tanggal dan jam lokal, mis. "28/10/2026 14:05".
String formatTanggalJam(DateTime d) {
  final l = d.toLocal();
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${dua(l.day)}/${dua(l.month)}/${l.year} ${dua(l.hour)}:${dua(l.minute)}';
}
