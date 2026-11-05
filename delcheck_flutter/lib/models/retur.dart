/// Informasi pesanan yang disertakan dalam ReturResource.
class ReturPesanan {
  final int id;
  final String nomor;

  const ReturPesanan({required this.id, required this.nomor});

  factory ReturPesanan.fromJson(Map<String, dynamic> json) => ReturPesanan(
    id: _returInt(json['id']),
    nomor: _returString(json['nomor']) ?? '-',
  );
}

/// Ringkasan toko pada ReturResource.
class ReturRetailer {
  final int id;
  final String? kode;
  final String? namaToko;

  const ReturRetailer({required this.id, this.kode, this.namaToko});

  factory ReturRetailer.fromJson(Map<String, dynamic> json) => ReturRetailer(
    id: _returInt(json['id']),
    kode: _returString(json['kode']),
    namaToko: _returString(json['nama_toko']),
  );
}

/// Ringkasan produk dari relasi item Return.
class ReturProduk {
  final int id;
  final String? kode;
  final String? nama;
  final String? satuan;

  const ReturProduk({required this.id, this.kode, this.nama, this.satuan});

  factory ReturProduk.fromJson(Map<String, dynamic> json) => ReturProduk(
    id: _returInt(json['id']),
    kode: _returString(json['kode']),
    nama: _returString(json['nama']),
    satuan: _returString(json['satuan']),
  );
}

/// Satu item produk pada Return.
class ReturItem {
  final int id;
  final int itemPesananId;
  final int produkId;
  final ReturProduk? produk;
  final String? namaProdukPesanan;
  final int qty;

  const ReturItem({
    required this.id,
    required this.itemPesananId,
    required this.produkId,
    this.produk,
    this.namaProdukPesanan,
    required this.qty,
  });

  factory ReturItem.fromJson(Map<String, dynamic> json) => ReturItem(
    id: _returInt(json['id']),
    itemPesananId: _returInt(json['item_pesanan_id']),
    produkId: _returInt(json['produk_id']),
    produk: _returMap(json['produk']) == null
        ? null
        : ReturProduk.fromJson(_returMap(json['produk'])!),
    namaProdukPesanan: _returString(json['nama_produk_pesanan']),
    qty: _returInt(json['qty']),
  );
}

/// Foto pada ReturResource. [url] adalah endpoint terautentikasi, bukan path
/// penyimpanan file.
class ReturFoto {
  final int id;
  final String jenis;
  final String url;
  final String? mime;
  final int? ukuran;

  const ReturFoto({
    required this.id,
    required this.jenis,
    required this.url,
    this.mime,
    this.ukuran,
  });

  factory ReturFoto.fromJson(Map<String, dynamic> json) => ReturFoto(
    id: _returInt(json['id']),
    jenis: _returString(json['jenis']) ?? '',
    url: _returString(json['url']) ?? '',
    mime: _returString(json['mime']),
    ukuran: _returNullableInt(json['ukuran']),
  );
}

/// Data Return sesuai field yang dikirim oleh Laravel ReturResource.
class Retur {
  static const String statusDraft = 'draft';
  static const String statusDiajukan = 'diajukan';
  static const String statusDitolak = 'ditolak';
  static const String statusDisetujui = 'disetujui';
  static const String statusDijadwalkan = 'dijadwalkan';
  static const String statusDijemput = 'dijemput';

  final int id;
  final String nomor;
  final ReturPesanan? pesanan;
  final ReturRetailer? retailer;
  final String status;
  final String statusLabel;
  final String? alasan;
  final String? alasanDitolak;
  final String? jenisPenyelesaian;
  final ReturItem? item;
  final List<ReturFoto> fotoKondisi;
  final DateTime? jadwalJemput;
  final String? catatanJemput;
  final List<ReturFoto> fotoPenjemputan;
  final String? pengaju;
  final String? dikonfirmasiOleh;
  final DateTime? dikonfirmasiAt;
  final DateTime? dijemputAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Retur({
    required this.id,
    required this.nomor,
    this.pesanan,
    this.retailer,
    required this.status,
    required this.statusLabel,
    this.alasan,
    this.alasanDitolak,
    this.jenisPenyelesaian,
    this.item,
    this.fotoKondisi = const [],
    this.jadwalJemput,
    this.catatanJemput,
    this.fotoPenjemputan = const [],
    this.pengaju,
    this.dikonfirmasiOleh,
    this.dikonfirmasiAt,
    this.dijemputAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == statusDraft;
  bool get isDiajukan => status == statusDiajukan;
  bool get isDitolak => status == statusDitolak;
  bool get isDisetujui => status == statusDisetujui;
  bool get isDijadwalkan => status == statusDijadwalkan;
  bool get isDijemput => status == statusDijemput;

  factory Retur.fromJson(Map<String, dynamic> json) {
    final pesanan = _returMap(json['pesanan']);
    final retailer = _returMap(json['retailer']);
    final item = _returMap(json['item']);

    return Retur(
      id: _returInt(json['id']),
      nomor: _returString(json['nomor']) ?? '-',
      pesanan: pesanan == null ? null : ReturPesanan.fromJson(pesanan),
      retailer: retailer == null ? null : ReturRetailer.fromJson(retailer),
      status: _returString(json['status']) ?? '',
      statusLabel: _returString(json['status_label']) ?? '',
      alasan: _returString(json['alasan']),
      alasanDitolak: _returString(json['alasan_ditolak']),
      jenisPenyelesaian: _returString(json['jenis_penyelesaian']),
      item: item == null ? null : ReturItem.fromJson(item),
      fotoKondisi: _returFotoList(json['foto_kondisi']),
      jadwalJemput: _returDate(json['jadwal_jemput']),
      catatanJemput: _returString(json['catatan_jemput']),
      fotoPenjemputan: _returFotoList(json['foto_penjemputan']),
      pengaju: _returString(json['pengaju']),
      dikonfirmasiOleh: _returString(json['dikonfirmasi_oleh']),
      dikonfirmasiAt: _returDate(json['dikonfirmasi_at']),
      dijemputAt: _returDate(json['dijemput_at']),
      createdAt: _returDate(json['created_at']),
      updatedAt: _returDate(json['updated_at']),
    );
  }
}

Map<String, dynamic>? _returMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

List<ReturFoto> _returFotoList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(_returMap)
      .whereType<Map<String, dynamic>>()
      .map(ReturFoto.fromJson)
      .toList();
}

String? _returString(dynamic value) {
  final string = value?.toString().trim();
  return string == null || string.isEmpty || string == 'null' ? null : string;
}

int _returInt(dynamic value) => _returNullableInt(value) ?? 0;

int? _returNullableInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

DateTime? _returDate(dynamic value) =>
    DateTime.tryParse(_returString(value) ?? '');
