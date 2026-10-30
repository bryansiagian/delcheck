import '../core/api_client.dart';
import '../models/pengguna.dart';

/// Kelola akun pengguna (khusus admin, izin pengguna.kelola).
class PenggunaService {
  PenggunaService(this._api);

  final ApiClient _api;

  static const _base = '/admin/pengguna';

  /// GET /admin/pengguna?q=&role=&aktif=1|0&page=&per_page=
  Future<PagedPengguna> daftar({
    String? q,
    String? role,
    bool? aktif,
    int page = 1,
    int perPage = 15,
  }) async {
    final query = Uri(queryParameters: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (role != null) 'role': role,
      if (aktif != null) 'aktif': aktif ? '1' : '0',
      'page': '$page',
      'per_page': '$perPage',
    }).query;

    final body = await _api.get('$_base?$query');
    final data = body['data'] as Map<String, dynamic>;
    final meta = (data['meta'] ?? {}) as Map<String, dynamic>;

    return PagedPengguna(
      items: (data['items'] as List)
          .map((e) => Pengguna.fromJson(e as Map<String, dynamic>))
          .toList(),
      halaman: (meta['halaman'] ?? 1) as int,
      halamanTerakhir: (meta['halaman_terakhir'] ?? 1) as int,
      total: (meta['total'] ?? 0) as int,
    );
  }

  Future<({String pesan, Pengguna pengguna})> aktifkan(int id) => _ubah(id, 'aktifkan');

  Future<({String pesan, Pengguna pengguna})> nonaktifkan(int id) => _ubah(id, 'nonaktifkan');

  Future<({String pesan, Pengguna pengguna})> _ubah(int id, String aksi) async {
    final body = await _api.post('$_base/$id/$aksi');
    return (
      pesan: body['message']?.toString() ?? 'Berhasil.',
      pengguna: Pengguna.fromJson(body['data'] as Map<String, dynamic>),
    );
  }
}
