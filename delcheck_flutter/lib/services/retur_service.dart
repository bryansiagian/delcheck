import 'dart:io';
import 'dart:typed_data';

import '../core/api_client.dart';
import '../models/retur.dart';

/// Hasil daftar Return yang dipaginasi.
class HalamanRetur {
  final List<Retur> items;
  final int halaman;
  final int halamanTerakhir;
  final int total;

  const HalamanRetur({
    required this.items,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });
}

/// Endpoint Return. Hak akses dan transisi status tetap ditegakkan backend.
class ReturService {
  ReturService(this._api);

  final ApiClient _api;

  int _int(dynamic value, int fallback) =>
      value is num ? value.toInt() : (int.tryParse('$value') ?? fallback);

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final data = body['data'];
    return data is Map<String, dynamic> ? data : body;
  }

  Retur _retur(Map<String, dynamic> body) => Retur.fromJson(_data(body));

  /// Daftar Return dengan filter backend `status`, `q`, `page`, `per_page`.
  Future<HalamanRetur> daftar({
    String? status,
    String q = '',
    int halaman = 1,
    int perPage = 15,
  }) async {
    final query = <String, String>{
      'page': '$halaman',
      'per_page': '$perPage',
      if (status != null && status.isNotEmpty) 'status': status,
      if (q.trim().isNotEmpty) 'q': q.trim(),
    };
    final body = await _api.get(
      Uri(path: '/retur', queryParameters: query).toString(),
    );
    final data = _data(body);
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};

    return HalamanRetur(
      items: rawItems
          .whereType<Map>()
          .map((item) => Retur.fromJson(_asStringMap(item)))
          .toList(),
      halaman: _int(meta['halaman'], halaman),
      halamanTerakhir: _int(meta['halaman_terakhir'], 1),
      total: _int(meta['total'], rawItems.length),
    );
  }

  Future<Retur> detail(int id) async => _retur(await _api.get('/retur/$id'));

  /// Foto kondisi opsional pada draft; jika tersedia, request dikirim multipart.
  Future<Retur> buatDraft({
    required int pesananId,
    required int itemPesananId,
    required int qty,
    required String alasan,
    String? jenisPenyelesaian,
    List<File> fotoKondisi = const [],
  }) async {
    final fields = <String, dynamic>{
      'pesanan_id': pesananId,
      'item_pesanan_id': itemPesananId,
      'qty': qty,
      'alasan': alasan,
      if (jenisPenyelesaian != null) 'jenis_penyelesaian': jenisPenyelesaian,
    };

    if (fotoKondisi.isEmpty) {
      return _retur(await _api.post('/retur', body: fields));
    }

    return _retur(
      await _api.postMultipart(
        '/retur',
        fields: fields,
        files: {'foto_kondisi[]': fotoKondisi},
      ),
    );
  }

  /// Mengubah draft. Bila foto baru diberikan, POST multipart dengan
  /// `_method=PUT` digunakan agar kompatibel pada versi PHP lintas deployment.
  Future<Retur> perbaruiDraft(
    int id, {
    required Map<String, dynamic> data,
    List<File>? fotoKondisi,
  }) async {
    final fields = Map<String, dynamic>.from(data)..remove('foto_kondisi');
    if (fotoKondisi == null || fotoKondisi.isEmpty) {
      return _retur(await _api.put('/retur/$id', body: fields));
    }

    fields['_method'] = 'PUT';
    return _retur(
      await _api.postMultipart(
        '/retur/$id',
        fields: fields,
        files: {'foto_kondisi[]': fotoKondisi},
      ),
    );
  }

  Future<String> hapusDraft(int id) async {
    final body = await _api.delete('/retur/$id');
    return body['message']?.toString() ?? 'Draft Return berhasil dihapus.';
  }

  Future<Retur> ajukan(int id) async =>
      _retur(await _api.post('/retur/$id/ajukan'));

  Future<Retur> setujui(int id) async =>
      _retur(await _api.post('/retur/$id/setujui'));

  Future<Retur> tolak(int id, String alasan) async =>
      _retur(await _api.post('/retur/$id/tolak', body: {'alasan': alasan}));

  Future<Retur> jadwalkanPenjemputan(
    int id, {
    required String jadwalJemput,
    String? catatanJemput,
  }) async => _retur(
    await _api.put(
      '/retur/$id/jadwal-penjemputan',
      body: {
        'jadwal_jemput': jadwalJemput,
        if (catatanJemput != null) 'catatan_jemput': catatanJemput,
      },
    ),
  );

  Future<Retur> unggahBuktiPenjemputan(
    int id,
    List<File> fotoPenjemputan,
  ) async => _retur(
    await _api.postMultipart(
      '/retur/$id/bukti-penjemputan',
      files: {'foto_penjemputan[]': fotoPenjemputan},
    ),
  );

  /// Bytes gambar didapat melalui URL Resource yang terautentikasi.
  Future<Uint8List> ambilFoto(String url) => _api.getBytes(url);
}

Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> value) =>
    value.map((key, item) => MapEntry('$key', item));
