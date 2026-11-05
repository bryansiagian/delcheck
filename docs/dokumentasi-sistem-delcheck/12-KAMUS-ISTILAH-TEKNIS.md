# 12 — Kamus Istilah Teknis

| Istilah | Definisi dan kegunaan | Lokasi penerapan Delcheck |
|---|---|---|
| `StatelessWidget` | Widget tanpa state yang berubah sendiri; build berdasarkan input | Komponen/helper seperti chip status |
| `StatefulWidget` | Widget dengan objek State dan lifecycle | Screens dengan form, pencarian, loading |
| `BuildContext` | Referensi posisi widget dalam tree untuk dependency, navigator, theme | `context.read<ApiClient>()`, `Navigator` |
| `setState` | Menandai state screen berubah agar `build()` dijalankan lagi | `_muatAwal`, aksi mutation |
| `Future` / `async` / `await` | Representasi proses asynchronous dan menunggu hasilnya | HTTP calls dan storage |
| `ChangeNotifier` | Objek state yang mengirim notifikasi saat berubah | `AuthProvider` |
| Provider | Mekanisme menyuntikkan objek ke widget tree dan mengaksesnya | `MultiProvider` di `main.dart` |
| Debounce | Menunda request hingga input berhenti berubah sesaat | Timer 500 ms pencarian retailer |
| Pagination | Membagi hasil daftar menjadi halaman | `page`, `per_page`, meta API |
| JSON serialization/parsing | Mengubah struktur JSON ke object Dart/PHP resource | `fromJson`, JsonResource |
| REST-style API | Endpoint HTTP dengan resource dan method/action | `/api/produk`, `/api/pesanan/{id}/kirim` |
| Middleware | Kode sebelum controller untuk auth/permission/throttle | route API Laravel |
| FormRequest | Class validasi dan otorisasi request | `TolakRetailRequest`, `LoginRequest` |
| Controller | Menerima request dan mengatur orchestration | `PendaftaranRetailController` |
| Service layer | Menempatkan aturan bisnis reusable/transaksi | `VerifikasiRetailService`, `PesananService` |
| Eloquent ORM | Mapping model PHP ke tabel/query database | `Retailer`, `Pesanan`, `User` |
| JsonResource | Memilih field model yang diserialisasi | `RetailerResource`, `PesananResource` |
| Migration | Versi deklaratif perubahan struktur tabel | `database/migrations` |
| Foreign key | Constraint hubungan antar tabel | `retailers.user_id`, `pesanan.retailer_id` |
| Pivot table | Tabel penghubung relasi many-to-many | `sales_assignments`, tabel Spatie |
| Soft delete | Menandai `deleted_at` tanpa hapus fisik record lewat Eloquent | `User`, `Retailer`, `Produk` |
| Transaction | Membuat beberapa operasi database commit/rollback sebagai kesatuan | Verifikasi, order, stok, pengguna |
| `lockForUpdate` | Mengunci record selama transaksi agar perubahan bersamaan terserialisasi | status pesanan/stok/akun |
| Audit trail | Catatan siapa melakukan transisi dan kapan | `AuditLog::catat`, `audit_logs` |
| Sanctum | Token API Laravel untuk request mobile | `HasApiTokens`, `auth:sanctum` |
| RBAC / Permission | Role-based access control dan izin granular | Spatie permission seeder/middleware |
| Bearer token | Token sesi dikirim di header Authorization | `ApiClient._headers` |
| HTTP 401/403/404/409/422 | Status gagal: sesi/izin/resource/konflik/validasi | `ApiClient._toException` |
| Git working tree | Perubahan lokal dibanding commit | `git status`; tidak mengubah Git selama audit |

## Contoh yang diambil dari kode

Flutter memanggil `await _service.daftar(status: _status, q: _q, halaman: 1)` lalu `setState` mengganti list. Backend query Eloquent `Retailer::query()->with(['user', 'wilayah', ...])->where(...)->paginate(...)`. Migration adalah definisi tabel; tidak sama dengan bukti kondisi DB aktual. Route middleware `permission:retailer.verifikasi` adalah otorisasi server, berbeda dari menyembunyikan tombol di UI.
