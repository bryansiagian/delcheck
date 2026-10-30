DateTime? _tgl(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class Pengguna {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final bool isActive;
  final List<String> roles;
  final DateTime? lastLoginAt;

  /// Hanya untuk akun Retail.
  final String? namaToko;
  final String? statusToko;

  const Pengguna({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.isActive,
    this.roles = const [],
    this.lastLoginAt,
    this.namaToko,
    this.statusToko,
  });

  String get peranLabel => roles.isEmpty
      ? '-'
      : roles
          .map((r) => r.isEmpty ? r : r[0].toUpperCase() + r.substring(1))
          .join(', ');

  /// Akun toko yang pendaftarannya belum disetujui: aktivasi lewat menu verifikasi.
  bool get tokoBelumDisetujui => statusToko != null && statusToko != 'disetujui';

  factory Pengguna.fromJson(Map<String, dynamic> j) {
    final retailer = j['retailer'];
    final roles = j['roles'];
    return Pengguna(
      id: j['id'] as int,
      name: (j['name'] ?? '').toString(),
      email: j['email']?.toString(),
      phone: j['phone']?.toString(),
      isActive: j['is_active'] == true,
      roles: roles is List ? roles.map((e) => e.toString()).toList() : const [],
      lastLoginAt: _tgl(j['last_login_at']),
      namaToko: retailer is Map ? retailer['nama_toko']?.toString() : null,
      statusToko: retailer is Map ? retailer['status_verifikasi']?.toString() : null,
    );
  }
}

class PagedPengguna {
  final List<Pengguna> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const PagedPengguna({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}
