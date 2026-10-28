import '../core/api_client.dart';
import '../models/produk.dart';

class HalamanProduk {
  final List<Produk> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const HalamanProduk({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}

/// Endpoint katalog produk. Tambah/ubah/hapus butuh izin produk.kelola.
class ProdukService {
  ProdukService(this._api);

  final ApiClient _api;

  int _int(dynamic v, int bawaan) =>
      v is num ? v.toInt() : (int.tryParse('$v') ?? bawaan);

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final d = body['data'];
    return d is Map<String, dynamic> ? d : body;
  }

  /// [status]: 'semua' | 'aktif' | 'nonaktif'
  Future<HalamanProduk> daftar({
    String q = '',
    String status = 'semua',
    int halaman = 1,
  }) async {
    final query = <String, String>{
      'page': '$halaman',
      'per_page': '15',
      if (status != 'semua') 'status': status,
      if (q.trim().isNotEmpty) 'q': q.trim(),
    };
    final body = await _api
        .get(Uri(path: '/produk', queryParameters: query).toString());

    final data = _data(body);
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanProduk(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(Produk.fromJson)
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
      total: _int(meta['total'], rawItems.length),
    );
  }

  Future<Produk> tambah(Map<String, dynamic> data) async {
    final body = await _api.post('/produk', body: data);
    return Produk.fromJson(_data(body));
  }

  Future<Produk> ubah(int id, Map<String, dynamic> data) async {
    final body = await _api.put('/produk/$id', body: data);
    return Produk.fromJson(_data(body));
  }

  Future<String> hapus(int id) async {
    final body = await _api.delete('/produk/$id');
    return body['message']?.toString() ?? 'Produk dihapus.';
  }
}
