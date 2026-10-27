import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { memeriksa, masuk, keluar }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiClient api, FlutterSecureStorage? storage})
      : _api = api,
        _service = AuthService(api),
        _storage = storage ?? const FlutterSecureStorage() {
    // Token ditolak server -> kembali ke halaman login.
    _api.onUnauthorized = () {
      if (_status == AuthStatus.masuk) _bersihkanSesi();
    };
  }

  static const _kToken = 'auth_token';

  final ApiClient _api;
  final AuthService _service;
  final FlutterSecureStorage _storage;

  AuthStatus _status = AuthStatus.memeriksa;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// Dipanggil sekali saat aplikasi dibuka: pulihkan sesi jika ada token.
  Future<void> mulai() async {
    final token = await _storage.read(key: _kToken);
    if (token == null) {
      _status = AuthStatus.keluar;
      notifyListeners();
      return;
    }

    _api.token = token;
    try {
      _user = await _service.me();
      _status = AuthStatus.masuk;
    } on ApiException catch (e) {
      // 401 sudah ditangani onUnauthorized. Untuk error jaringan, tetap
      // minta login ulang agar tidak terjebak di layar pemuatan.
      if (!e.isUnauthorized) await _bersihkanSesi(notify: false);
      _status = AuthStatus.keluar;
    }
    notifyListeners();
  }

  /// Melempar [ApiException] jika gagal; UI yang menampilkan pesannya.
  Future<void> login(String identitas, String password) async {
    final hasil = await _service.login(identitas.trim(), password);

    _api.token = hasil.token;
    await _storage.write(key: _kToken, value: hasil.token);

    try {
      _user = hasil.user ?? await _service.me();
    } catch (e) {
      await _bersihkanSesi();
      rethrow;
    }

    _status = AuthStatus.masuk;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } on ApiException {
      // Abaikan: tetap hapus sesi lokal meski server tak terjangkau.
    }
    await _bersihkanSesi();
  }

  Future<void> _bersihkanSesi({bool notify = true}) async {
    _api.token = null;
    _user = null;
    _status = AuthStatus.keluar;
    await _storage.delete(key: _kToken);
    if (notify) notifyListeners();
  }
}
