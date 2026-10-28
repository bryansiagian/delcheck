String? _s(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty || t == 'null') ? null : t;
}

/// Data pendaftaran toko (Retailer) untuk halaman verifikasi admin.
/// Parser dibuat toleran terhadap beberapa kemungkinan nama field.
class RetailerPendaftar {
  final int id;
  final String kode;
  final String namaToko;
  final String? namaPemilik;
  final String alamat;
  final String? telepon;
  final String? email;
  final String? wilayah;
  final String status; // menunggu | disetujui | ditolak
  final String? alasanDitolak;
  final DateTime? dibuat;

  const RetailerPendaftar({
    required this.id,
    required this.kode,
    required this.namaToko,
    this.namaPemilik,
    required this.alamat,
    this.telepon,
    this.email,
    this.wilayah,
    required this.status,
    this.alasanDitolak,
    this.dibuat,
  });

  bool get menunggu => status == 'menunggu';
  bool get ditolak => status == 'ditolak';

  /// Boleh disetujui: pendaftaran baru, atau yang sebelumnya ditolak (setujui ulang).
  bool get bisaDisetujui => menunggu || ditolak;

  /// Penolakan hanya untuk pendaftaran yang masih menunggu.
  bool get bisaDitolak => menunggu;

  String get statusLabel =>
      status.isEmpty ? '-' : status[0].toUpperCase() + status.substring(1);

  factory RetailerPendaftar.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map<String, dynamic>
        ? j['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final rawStatus = j['status_verifikasi'];
    final status = rawStatus is Map
        ? (_s(rawStatus['value']) ?? _s(rawStatus['label']) ?? '')
        : (_s(rawStatus) ?? '');

    final rawWilayah = j['wilayah'];
    final wilayah = rawWilayah is Map
        ? _s(rawWilayah['nama'])
        : _s(rawWilayah ?? j['wilayah_nama']);

    return RetailerPendaftar(
      id: j['id'] is num ? (j['id'] as num).toInt() : int.parse('${j['id']}'),
      kode: _s(j['kode']) ?? '-',
      namaToko: _s(j['nama_toko']) ?? '-',
      namaPemilik: _s(j['nama_pemilik']) ?? _s(user['name']),
      alamat: _s(j['alamat']) ?? '-',
      telepon: _s(j['telepon']) ?? _s(j['phone']) ?? _s(user['phone']),
      email: _s(j['email']) ?? _s(user['email']),
      wilayah: wilayah,
      status: status.toLowerCase(),
      alasanDitolak: _s(j['alasan_ditolak']),
      dibuat: DateTime.tryParse(_s(j['created_at']) ?? ''),
    );
  }
}

class SalesUser {
  final int id;
  final String nama;
  final String? kontak;

  const SalesUser({required this.id, required this.nama, this.kontak});

  factory SalesUser.fromJson(Map<String, dynamic> j) => SalesUser(
        id: j['id'] is num ? (j['id'] as num).toInt() : int.parse('${j['id']}'),
        nama: _s(j['name']) ?? _s(j['nama']) ?? _s(j['email']) ?? 'Sales',
        kontak: _s(j['email']) ?? _s(j['phone']),
      );
}
