import '../core/api_client.dart';
import '../models/pesanan.dart';

class HalamanPesanan {
  final List<Pesanan> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const HalamanPesanan({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}

/// Endpoint pesanan. Hak akses dijaga server sesuai peran.
class PesananService {
  PesananService(this._api);

  final ApiClient _api;

  int _int(dynamic v, int bawaan) =>
      v is num ? v.toInt() : (int.tryParse('$v') ?? bawaan);

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final d = body['data'];
    return d is Map<String, dynamic> ? d : body;
  }

  /// [status] boleh beberapa nilai dipisah koma, mis. "dikonfirmasi,diproses".
  Future<HalamanPesanan> daftar({
    String? status,
    String q = '',
    int halaman = 1,
  }) async {
    final query = <String, String>{
      'page': '$halaman',
      'per_page': '15',
      if (status != null && status.isNotEmpty) 'status': status,
      if (q.trim().isNotEmpty) 'q': q.trim(),
    };
    final body = await _api
        .get(Uri(path: '/pesanan', queryParameters: query).toString());

    final data = _data(body);
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanPesanan(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(Pesanan.fromJson)
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
      total: _int(meta['total'], rawItems.length),
    );
  }

  Future<Pesanan> detail(int id) async =>
      Pesanan.fromJson(_data(await _api.get('/pesanan/$id')));

  /// [items]: daftar {produk_id, qty}.
  Future<Pesanan> buat({
    required List<Map<String, int>> items,
    String? catatan,
  }) async {
    final body = await _api.post('/pesanan', body: {
      'items': items,
      'catatan': catatan,
    });
    return Pesanan.fromJson(_data(body));
  }

  Future<Pesanan> _aksi(int id, String aksi, [Map<String, dynamic>? body]) async {
    final res = await _api.post('/pesanan/$id/$aksi', body: body);
    return Pesanan.fromJson(_data(res));
  }

  // Retail
  Future<Pesanan> batalkan(int id, String alasan) =>
      _aksi(id, 'batalkan', {'alasan': alasan});
  Future<Pesanan> terima(int id) => _aksi(id, 'terima');

  // Sales
  Future<Pesanan> setujui(int id) => _aksi(id, 'setujui');
  Future<Pesanan> tolak(int id, String alasan) =>
      _aksi(id, 'tolak', {'alasan': alasan});

  // Warehouse / Admin
  Future<Pesanan> proses(int id) => _aksi(id, 'proses');
  Future<Pesanan> kirim(int id, Map<String, dynamic> data) =>
      _aksi(id, 'kirim', data);
}
