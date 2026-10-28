import '../core/api_client.dart';
import '../models/stok.dart';

class HalamanStok {
  final List<StokProduk> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const HalamanStok({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}

class HalamanMutasi {
  final List<MutasiStok> items;
  final int halaman;
  final int halamanTerakhir;

  const HalamanMutasi({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
  });
}

/// Endpoint stok (izin stok.kelola: Admin dan Warehouse).
class StokService {
  StokService(this._api);

  final ApiClient _api;

  int _int(dynamic v, int bawaan) =>
      v is num ? v.toInt() : (int.tryParse('$v') ?? bawaan);

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final d = body['data'];
    return d is Map<String, dynamic> ? d : body;
  }

  Future<HalamanStok> daftar({
    String q = '',
    bool menipis = false,
    int halaman = 1,
  }) async {
    final query = <String, String>{
      'page': '$halaman',
      'per_page': '15',
      if (menipis) 'status': 'menipis',
      if (q.trim().isNotEmpty) 'q': q.trim(),
    };
    final body =
        await _api.get(Uri(path: '/stok', queryParameters: query).toString());

    final data = _data(body);
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanStok(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StokProduk.fromJson)
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
      total: _int(meta['total'], rawItems.length),
    );
  }

  Future<HalamanMutasi> riwayat(int produkId, {int halaman = 1}) async {
    final query = <String, String>{'page': '$halaman', 'per_page': '15'};
    final body = await _api.get(
        Uri(path: '/stok/$produkId/mutasi', queryParameters: query)
            .toString());

    final data = _data(body);
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanMutasi(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MutasiStok.fromJson)
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
    );
  }

  /// [tipe]: 'masuk' (tambah) atau 'keluar' (kurangi, alasan wajib).
  /// Mengembalikan stok terbaru produk.
  Future<StokProduk> ubah(
    int produkId, {
    required String tipe,
    required int jumlah,
    String? alasan,
  }) async {
    final body = await _api.post('/stok/$produkId/mutasi', body: {
      'tipe': tipe,
      'jumlah': jumlah,
      'alasan': alasan,
    });
    return StokProduk.fromJson(_data(body));
  }
}
