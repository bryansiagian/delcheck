import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/wilayah.dart';

/// Error 422 dari server: pesan umum + pesan per field.
class ApiValidationException implements Exception {
  final String message;
  final Map<String, String> fieldErrors;
  ApiValidationException(this.message, this.fieldErrors);
}

/// Error lain (jaringan, 5xx, dll).
class RegisterException implements Exception {
  final String message;
  RegisterException(this.message);
  @override
  String toString() => message;
}

class RegisterPayload {
  final String name;
  final String? email;
  final String? phone;
  final String password;
  final String namaToko;
  final String? namaPemilik;
  final String alamat;
  final int? wilayahId;

  RegisterPayload({
    required this.name,
    this.email,
    this.phone,
    required this.password,
    required this.namaToko,
    this.namaPemilik,
    required this.alamat,
    this.wilayahId,
  });

  /// Field kosong tidak dikirim, supaya aturan `nullable` /
  /// `required_without` di server bekerja benar.
  Map<String, dynamic> toJson() => {
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
        'nama_toko': namaToko,
        if (namaPemilik != null) 'nama_pemilik': namaPemilik,
        'alamat': alamat,
        if (wilayahId != null) 'wilayah_id': wilayahId,
      };
}

class RegisterService {
  /// Default memakai AppConfig.baseUrl (sudah berakhiran '/api').
  final String baseUrl;
  final http.Client _client;

  RegisterService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.baseUrl,
        _client = client ?? http.Client();

  static const _headers = {
    'Accept': 'application/json', // wajib, agar Laravel membalas 422 sebagai JSON
    'Content-Type': 'application/json',
  };

  /// GET {baseUrl}/wilayah?tingkat=...&parent_id=...
  Future<List<Wilayah>> fetchWilayah({String? tingkat, int? parentId}) async {
    final uri = Uri.parse('$baseUrl/wilayah').replace(queryParameters: {
      if (tingkat != null) 'tingkat': tingkat,
      if (parentId != null) 'parent_id': '$parentId',
    });
    final res = await _send(() => _client.get(uri, headers: _headers));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw RegisterException(body['message']?.toString() ?? 'Gagal memuat wilayah.');
    }
    return (body['data'] as List)
        .map((e) => Wilayah.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST {baseUrl}/auth/register. Mengembalikan pesan sukses dari server.
  Future<String> register(RegisterPayload payload) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final res = await _send(
      () => _client.post(uri, headers: _headers, body: jsonEncode(payload.toJson())),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw RegisterException('Respons server tidak valid (${res.statusCode}).');
    }

    if (res.statusCode == 201 || res.statusCode == 200) {
      return body['message']?.toString() ??
          'Pendaftaran berhasil. Akun Anda menunggu verifikasi Admin.';
    }

    if (res.statusCode == 422) {
      final errors = <String, String>{};
      final raw = body['errors'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            errors[key.toString()] = value.first.toString();
          } else if (value != null) {
            errors[key.toString()] = value.toString();
          }
        });
      }
      throw ApiValidationException(
        body['message']?.toString() ?? 'Data tidak valid.',
        errors,
      );
    }

    throw RegisterException(body['message']?.toString() ?? 'Terjadi kesalahan (${res.statusCode}).');
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(AppConfig.timeout);
    } catch (_) {
      throw RegisterException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }
}
