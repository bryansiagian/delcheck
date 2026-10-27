/// Konfigurasi aplikasi.
///
/// Ganti [baseUrl] sesuai tempat backend berjalan:
///  - Emulator Android  : http://10.0.2.2:8000/api
///  - HP fisik (satu WiFi): http://IP-LAPTOP:8000/api  (jalankan: php artisan serve --host=0.0.0.0)
///  - Server (EC2/domain): https://domain-anda.com/api
class AppConfig {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const Duration timeout = Duration(seconds: 20);
}