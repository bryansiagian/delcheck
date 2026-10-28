import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _send(() => _client.post(_uri(path),
          headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send(() => _client.put(_uri(path),
          headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(AppConfig.timeout);
    } on TimeoutException {
      throw ApiException(
          message: 'Server tidak merespons. Coba lagi beberapa saat.');
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      throw ApiException(
          message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.');
    } on http.ClientException catch (e) {
      debugPrint('ClientException: $e');
      throw ApiException(
          message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.');
    }

    Map<String, dynamic> body = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Body bukan JSON (mis. halaman error HTML). Ditangani di bawah.
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (res.statusCode == 401) onUnauthorized?.call();
    throw _toException(res.statusCode, body);
  }

  ApiException _toException(int status, Map<String, dynamic> body) {
    final errors = <String, List<String>>{};
    final rawErrors = body['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((k, v) {
        errors[k.toString()] =
            v is List ? v.map((e) => e.toString()).toList() : [v.toString()];
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
