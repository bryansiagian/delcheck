import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';

class HalamanRetailer {
  final List<RetailerPendaftar> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const HalamanRetailer({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}

/// Endpoint admin: verifikasi pendaftaran retail (izin retailer.verifikasi).
class AdminService {
  AdminService(this._api);

  final ApiClient _api;

  int _int(dynamic v, int bawaan) =>
      v is num ? v.toInt() : (int.tryParse('$v') ?? bawaan);

  Future<HalamanRetailer> daftar({
    required String status,
    String q = '',
    int halaman = 1,
  }) async {
    final query = <String, String>{
      'status': status,
      'page': '$halaman',
      'per_page': '15',
      if (q.trim().isNotEmpty) 'q': q.trim(),
    };
    final body = await _api.get(
        Uri(path: '/admin/pendaftaran-retail', queryParameters: query)
            .toString());

    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanRetailer(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(RetailerPendaftar.fromJson)
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
      total: _int(meta['total'], rawItems.length),
    );
  }

  /// Menyetujui pendaftaran. Tidak ada penugasan sales.
  /// Mengembalikan pesan sukses dari server.
  Future<String> setujui(int retailerId) async {
    final body =
        await _api.post('/admin/pendaftaran-retail/$retailerId/setujui');
    return body['message']?.toString() ?? 'Pendaftaran disetujui.';
  }

  Future<String> tolak(int retailerId, String alasan) async {
    final body = await _api.post(
      '/admin/pendaftaran-retail/$retailerId/tolak',
      body: {'alasan': alasan},
    );
    return body['message']?.toString() ?? 'Pendaftaran ditolak.';
  }
}
