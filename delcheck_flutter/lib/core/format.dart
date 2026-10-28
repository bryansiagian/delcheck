/// Format angka menjadi rupiah, mis. 95000 -> "Rp 95.000".
String formatRupiah(num nilai) {
  final bulat = nilai.round();
  final digit = bulat.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) buf.write('.');
    buf.write(digit[i]);
  }
  final tanda = bulat < 0 ? '-' : '';
  return '${tanda}Rp $buf';
}
