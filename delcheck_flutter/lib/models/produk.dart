double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
bool _b(dynamic v) => v is bool ? v : (v == 1 || v == '1' || v == 'true');

String? _s(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty || t == 'null') ? null : t;
}

class Produk {
  final int id;
  final String kode;
  final String nama;
  final String? deskripsi;
  final String satuan;
  final double harga;
  final int stokMinimum;
  final bool aktif;

  const Produk({
    required this.id,
    required this.kode,
    required this.nama,
    this.deskripsi,
    required this.satuan,
    required this.harga,
    required this.stokMinimum,
    required this.aktif,
  });

  factory Produk.fromJson(Map<String, dynamic> j) => Produk(
        id: _i(j['id']),
        kode: _s(j['kode']) ?? '-',
        nama: _s(j['nama']) ?? '-',
        deskripsi: _s(j['deskripsi']),
        satuan: _s(j['satuan']) ?? '-',
        harga: _d(j['harga']),
        stokMinimum: _i(j['stok_minimum']),
        aktif: _b(j['is_active']),
      );
}
