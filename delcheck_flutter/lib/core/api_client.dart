import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// Error dari API, sudah dalam bentuk yang mudah dipakai UI.
class ApiException implements Exception {
  final int? status;

  /// Kode error dari backend, mis. TIDAK_PUNYA_AKSES, AKUN_DITOLAK.
  final String? kode;
  final String message;

  /// Error validasi (422): nama field -> daftar pesan.
  final Map<String, List<String>> errors;

  ApiException({
    this.status,
    this.kode,
    required this.message,
    this.errors = const {},
  });

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Token Sanctum. Diisi oleh AuthProvider.
  String? token;

  /// Dipanggil saat server menjawab 401 (sesi habis / token tidak valid).
  void Function()? onUnauthorized;

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Map<String, String> get _authHeaders => {
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, String> get _headers => {
    ..._authHeaders,
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _send(
    () => _client.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send(
        () => _client.put(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? {}),
        ),
      );

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  /// Mengirim multipart POST. Setiap daftar file pada [files] memakai nama
  /// field yang sama berulang kali, misalnya `foto_kondisi[]`.
  /// Content-Type sengaja dibiarkan dibuat oleh MultipartRequest agar boundary
  /// selalu sesuai dengan body.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, dynamic> fields = const {},
    Map<String, List<File>> files = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_authHeaders);

    fields.forEach((key, value) {
      // Field null yang eksplisit dikirim sebagai string kosong supaya Laravel
      // dapat mengonversinya menjadi null; field yang tidak disertakan tetap absen.
      request.fields[key] = value?.toString() ?? '';
    });

    try {
      for (final entry in files.entries) {
        for (final file in entry.value) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, file.path),
          );
        }
      }
    } on FileSystemException {
      throw ApiException(message: 'File foto tidak dapat dibaca.');
    }

    final response = await _perform(() async {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });

    return _decodeJsonResponse(response);
  }

  /// Mengambil bytes foto Return dengan Bearer Token.
  /// URL absolut hanya diterima jika berasal dari Base URL API proyek dan
  /// mengarah ke endpoint foto Return, agar token tidak dikirim ke host lain.
  Future<Uint8List> getBytes(String pathOrUrl) async {
    final uri = _fotoUri(pathOrUrl);
    final response = await _perform(
      () => _client.get(
        uri,
        headers: {
          'Accept': 'image/*, application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode == 200) return response.bodyBytes;

    if (response.statusCode == 401) onUnauthorized?.call();
    throw _toException(response.statusCode, _decodeBody(response));
  }

  Uri _fotoUri(String pathOrUrl) {
    final base = Uri.parse(AppConfig.baseUrl);
    final supplied = Uri.parse(pathOrUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/$'), '');

    if (supplied.hasScheme || supplied.hasAuthority) {
      if (!supplied.path.startsWith('$basePath/retur/')) {
        throw ApiException(message: 'URL foto Return tidak valid.');
      }
      // Pakai host Base URL lokal, sebab host absolut dari route Laravel dapat
      // berbeda di antara APP_URL dan alamat yang dipakai perangkat mobile.
      return base.replace(path: supplied.path, query: supplied.query);
    }

    if (!supplied.path.startsWith('/retur/')) {
      throw ApiException(message: 'Path foto Return tidak valid.');
    }

    return _uri(pathOrUrl);
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final res = await _perform(request);
    return _decodeJsonResponse(res);
  }

  Future<T> _perform<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(AppConfig.timeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Server tidak merespons. Coba lagi beberapa saat.',
      );
    } on SocketException {
      throw ApiException(
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response res) {
    final body = _decodeBody(res);

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (res.statusCode == 401) onUnauthorized?.call();
    throw _toException(res.statusCode, body);
  }

  Map<String, dynamic> _decodeBody(http.Response res) {
    Map<String, dynamic> body = {};
    try {
      final responseText = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (responseText.isNotEmpty) {
        final decoded = jsonDecode(responseText);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
    } catch (_) {
      // Body bukan JSON (mis. halaman error HTML). Ditangani di bawah.
    }
    return body;
  }

  ApiException _toException(int status, Map<String, dynamic> body) {
    final errors = <String, List<String>>{};
    final rawErrors = body['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((k, v) {
        errors[k.toString()] = v is List
            ? v.map((e) => e.toString()).toList()
            : [v.toString()];
      });
    }

    String? message = (body['pesan'] ?? body['message'])?.toString();
    if (errors.isNotEmpty && status == 422) {
      message = errors.values.first.first;
    }
    message ??= switch (status) {
      401 => 'Sesi berakhir. Silakan masuk kembali.',
      403 => 'Anda tidak memiliki akses.',
      404 => 'Data tidak ditemukan.',
      429 => 'Terlalu banyak percobaan. Coba lagi sebentar lagi.',
      >= 500 => 'Terjadi kesalahan di server. Coba lagi nanti.',
      _ => 'Terjadi kesalahan (kode $status).',
    };

    return ApiException(
      status: status,
      kode: body['kode']?.toString(),
      message: message,
      errors: errors,
    );
  }
}
