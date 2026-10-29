double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

String? _s(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty || t == 'null') ? null : t;
}

DateTime? _dt(dynamic v) => DateTime.tryParse(_s(v) ?? '');

const _labelStatus = {
  'diajukan': 'Diajukan',
  'menunggu_konfirmasi_sales': 'Menunggu konfirmasi',
  'dikonfirmasi': 'Dikonfirmasi',
  'ditolak': 'Ditolak',
  'diproses': 'Diserahkan ke kurir',
  'dikirim': 'Dalam perjalanan',
  'diterima': 'Diterima',
  'selesai': 'Selesai',
  'dibatalkan': 'Dibatalkan',
};

String labelStatusPesanan(String status) => _labelStatus[status] ?? status;

class ItemPesanan {
  final int id;
  final int produkId;
  final String namaProduk;
  final String satuan;
  final double harga;
  final int qty;
  final double subtotal;

  const ItemPesanan({
    required this.id,
    required this.produkId,
    required this.namaProduk,
    required this.satuan,
    required this.harga,
    required this.qty,
    required this.subtotal,
  });

  factory ItemPesanan.fromJson(Map<String, dynamic> j) => ItemPesanan(
        id: _i(j['id']),
        produkId: _i(j['produk_id']),
        namaProduk: _s(j['nama_produk']) ?? '-',
        satuan: _s(j['satuan']) ?? '',
        harga: _d(j['harga']),
        qty: _i(j['qty']),
        subtotal: _d(j['subtotal']),
      );
}

class PengirimanPesanan {
  final int id;
  final String? nomorSuratJalan;
  final String status; // dikirim | diterima
  final DateTime? tanggalKirim;
  final DateTime? estimasiTiba;
  final DateTime? diterimaAt;
  final String? catatan;

  const PengirimanPesanan({
    required this.id,
    this.nomorSuratJalan,
    required this.status,
    this.tanggalKirim,
    this.estimasiTiba,
    this.diterimaAt,
    this.catatan,
  });

  factory PengirimanPesanan.fromJson(Map<String, dynamic> j) =>
      PengirimanPesanan(
        id: _i(j['id']),
        nomorSuratJalan: _s(j['nomor_surat_jalan']),
        status: _s(j['status']) ?? '',
        tanggalKirim: _dt(j['tanggal_kirim']),
        estimasiTiba: _dt(j['estimasi_tiba']),
        diterimaAt: _dt(j['diterima_at']),
        catatan: _s(j['catatan']),
      );
}

class Pesanan {
  final int id;
  final String nomor;
  final String status;
  final double total;
  final String? catatan;
  final int jumlahItem;
  final String? tokoNama;
  final String? tokoKode;
  final String? salesNama;
  final List<ItemPesanan> items;
  final PengirimanPesanan? pengiriman;
  final String? alasanDitolak;
  final String? alasanBatal;
  final DateTime? dibuat;
  final DateTime? dikonfirmasiAt;
  final DateTime? diprosesAt;
  final DateTime? dikirimAt;
  final DateTime? diterimaAt;
  final DateTime? dibatalkanAt;

  const Pesanan({
    required this.id,
    required this.nomor,
    required this.status,
    required this.total,
    this.catatan,
    required this.jumlahItem,
    this.tokoNama,
    this.tokoKode,
    this.salesNama,
    this.items = const [],
    this.pengiriman,
    this.alasanDitolak,
    this.alasanBatal,
    this.dibuat,
    this.dikonfirmasiAt,
    this.diprosesAt,
    this.dikirimAt,
    this.diterimaAt,
    this.dibatalkanAt,
  });

  bool get menunggu => status == 'menunggu_konfirmasi_sales';

  String get statusLabel => labelStatusPesanan(status);

  factory Pesanan.fromJson(Map<String, dynamic> j) {
    final retailer = j['retailer'] is Map<String, dynamic>
        ? j['retailer'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = j['items'] is List ? j['items'] as List : const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(ItemPesanan.fromJson)
        .toList();

    return Pesanan(
      id: _i(j['id']),
      nomor: _s(j['nomor']) ?? '-',
      status: _s(j['status']) ?? '',
      total: _d(j['total']),
      catatan: _s(j['catatan']),
      jumlahItem: j['jumlah_item'] != null ? _i(j['jumlah_item']) : items.length,
      tokoNama: _s(retailer['nama_toko']),
      tokoKode: _s(retailer['kode']),
      salesNama: _s(j['sales']),
      items: items,
      pengiriman: j['pengiriman'] is Map<String, dynamic>
          ? PengirimanPesanan.fromJson(j['pengiriman'] as Map<String, dynamic>)
          : null,
      alasanDitolak: _s(j['alasan_ditolak']),
      alasanBatal: _s(j['alasan_batal']),
      dibuat: _dt(j['created_at']),
      dikonfirmasiAt: _dt(j['dikonfirmasi_at']),
      diprosesAt: _dt(j['diproses_at']),
      dikirimAt: _dt(j['dikirim_at']),
      diterimaAt: _dt(j['diterima_at']),
      dibatalkanAt: _dt(j['dibatalkan_at']),
    );
  }
}
