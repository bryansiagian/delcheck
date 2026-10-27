import '../core/api_client.dart';
import '../models/app_user.dart';

class LoginResult {
  final String token;
  final AppUser? user;
  const LoginResult(this.token, this.user);
}

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// [identitas] boleh email atau nomor telepon. Backend menolak jika
  /// keduanya dikirim sekaligus, jadi hanya satu field yang dikirim.
  Future<LoginResult> login(String identitas, String password) async {
    final isEmail = identitas.contains('@');
    final body = await _api.post('/auth/login', body: {
      if (isEmail) 'email': identitas else 'telepon': identitas,
      'password': password,
    });

    final payload = _unwrap(body);
    final token = (payload['token'] ??
            payload['access_token'] ??
            payload['plain_text_token'])
        ?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Respons login tidak berisi token.');
    }

    final userJson = payload['user'];
    return LoginResult(
      token,
      userJson is Map<String, dynamic> ? AppUser.fromJson(userJson) : null,
    );
  }

  Future<AppUser> me() async {
    final payload = _unwrap(await _api.get('/auth/me'));
    final userJson = payload['user'];
    return AppUser.fromJson(
        userJson is Map<String, dynamic> ? userJson : payload);
  }

  Future<void> logout() async {
    await _api.post('/auth/logout');
  }

  /// Respons sukses dibungkus di `data`.
  Map<String, dynamic> _unwrap(Map<String, dynamic> body) {
    final data = body['data'];
    return data is Map<String, dynamic> ? data : body;
  }
}
