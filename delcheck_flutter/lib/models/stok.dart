int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
bool _b(dynamic v) => v is bool ? v : (v == 1 || v == '1' || v == 'true');

String? _s(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty || t == 'null') ? null : t;
}

/// Produk beserta jumlah stoknya. [id] adalah id produk.
class StokProduk {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final bool aktif;
  final int stokMinimum;
  final int jumlah;
  final bool habis;
  final bool menipis; // jumlah <= stok minimum (termasuk habis)

  const StokProduk({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.aktif,
    required this.stokMinimum,
    required this.jumlah,
    required this.habis,
    required this.menipis,
  });

  factory StokProduk.fromJson(Map<String, dynamic> j) {
    final jumlah = _i(j['jumlah']);
    final min = _i(j['stok_minimum']);
    return StokProduk(
      id: _i(j['id']),
      kode: _s(j['kode']) ?? '-',
      nama: _s(j['nama']) ?? '-',
      satuan: _s(j['satuan']) ?? '',
      aktif: _b(j['is_active']),
      stokMinimum: min,
      jumlah: jumlah,
      habis: j['habis'] == null ? jumlah == 0 : _b(j['habis']),
      menipis: j['menipis'] == null ? jumlah <= min : _b(j['menipis']),
    );
  }
}

/// Satu catatan perubahan stok. [jumlah] bertanda: positif masuk, negatif keluar.
class MutasiStok {
  final int id;
  final String tipe;
  final int jumlah;
  final int stokSebelum;
  final int stokSesudah;
  final String? alasan;
  final String? oleh;
  final DateTime? dibuat;

  const MutasiStok({
    required this.id,
    required this.tipe,
    required this.jumlah,
    required this.stokSebelum,
    required this.stokSesudah,
    this.alasan,
    this.oleh,
    this.dibuat,
  });

  bool get masuk => jumlah > 0;

  factory MutasiStok.fromJson(Map<String, dynamic> j) => MutasiStok(
        id: _i(j['id']),
        tipe: _s(j['tipe']) ?? '',
        jumlah: _i(j['jumlah']),
        stokSebelum: _i(j['stok_sebelum']),
        stokSesudah: _i(j['stok_sesudah']),
        alasan: _s(j['alasan']),
        oleh: _s(j['dibuat_oleh']),
        dibuat: DateTime.tryParse(_s(j['created_at']) ?? ''),
      );
}
