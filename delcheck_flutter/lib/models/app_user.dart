class AppUser {
  final int? id;
  final String nama;
  final String? email;
  final String? telepon;
  final List<String> peran;

  const AppUser({
    this.id,
    required this.nama,
    this.email,
    this.telepon,
    this.peran = const [],
  });

  /// Peran utama untuk ditampilkan (huruf pertama kapital).
  String get peranUtama {
    if (peran.isEmpty) return '-';
    final p = peran.first;
    return p.isEmpty ? '-' : p[0].toUpperCase() + p.substring(1);
  }

  bool punyaPeran(String nama) =>
      peran.any((p) => p.toLowerCase() == nama.toLowerCase());

  /// Parser dibuat toleran terhadap beberapa kemungkinan nama field,
  /// karena bentuk respons `me`/`login` belum dikonfirmasi.
  factory AppUser.fromJson(Map<String, dynamic> j) {
    final rolesRaw = j['peran'] ?? j['roles'] ?? j['role'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        roles.add(r is Map ? (r['name'] ?? r['nama'] ?? '').toString() : r.toString());
      }
    } else if (rolesRaw != null) {
      roles.add(rolesRaw.toString());
    }

    return AppUser(
      id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}'),
      nama: (j['name'] ?? j['nama'] ?? j['email'] ?? 'Pengguna').toString(),
      email: j['email']?.toString(),
      telepon: (j['telepon'] ?? j['phone'])?.toString(),
      peran: roles,
    );
  }
}
