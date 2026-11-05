# 14 — Daftar Fitur dan Mapping Kode

## Fitur terhubung UI/API

| Fitur | Role | Flutter screen/service/model | Laravel endpoint/controller/service/tabel |
|---|---|---|---|
| Login, pulihkan sesi, logout | Semua | `login_screen.dart`, `AuthProvider`, `AuthService`, `ApiClient`, `AppUser` | `/auth/login,me,logout`; `AuthController`, `AuthService`, `UserResource`; users, personal_access_tokens |
| Pendaftaran Retail | Publik/Retail | `register_screen.dart`, `register_service.dart`, `Wilayah` | `/auth/register`, `/wilayah`; `AuthController`, `WilayahController`, `AuthService`; users, retailers, roles, wilayah |
| Verifikasi Retail | Admin | `admin_verifikasi_screen.dart`, `admin_detail_retailer_screen.dart`, `admin_service.dart`, `retailer_pendaftar.dart` | `/admin/pendaftaran-retail*`; `PendaftaranRetailController`, `VerifikasiRetailService`; retailers, users, sales_assignments optional, audit_logs |
| Kelola akun | Admin | `admin_pengguna_screen.dart`, `pengguna_service.dart`, `pengguna.dart` | `/admin/pengguna*`; `PenggunaController`, `PenggunaService`; users, roles/pivots, retailers, tokens |
| Produk | Admin/Warehouse; katalog Retail/Sales | `produk_list_screen.dart`, `produk_form_screen.dart`, `produk_service.dart`, `produk.dart` | `/produk*`; `ProdukController`, `ProdukRequest`, `ProdukResource`; produk, kategori_produk |
| Stok & histori | Admin/Warehouse | `stok_list_screen.dart`, `stok_detail_screen.dart`, `stok_service.dart`, `stok.dart` | `/stok*`; `StokController`, `StokService`; produk, stok_produk, mutasi_stok |
| Buat/pantau/transisi pesanan | Retail, Sales, Admin/Warehouse | `buat_pesanan_screen.dart`, `pesanan_list_screen.dart`, `pesanan_detail_screen.dart`, `pesanan_service.dart`, `pesanan.dart`; `CatatPengirimanBottomSheet`, `StatusPesananChip` | `/pesanan*`; `PesananController`, `PesananService`, `StokService`; pesanan, item_pesanan, pengiriman, mutasi_stok, audit_logs |

## Fitur hanya direncanakan/parsial

| Area | Bukti schema/izin | Gap source yang ditemukan |
|---|---|---|
| Laporan barang/klaim | migration `laporan_barang`, `item_laporan`, `klaim`, foto; permissions | tidak ada route/controller/service/screen lengkap |
| Retur/logistik retur | migration `retur`, `item_retur`; permissions | tidak ada endpoint/flow Flutter |
| Ulasan | migration `ulasan`, admin permission | tidak ada model/controller/route/screen |
| Jadwal & kinerja Sales | migrations kunjungan/target, permission | tidak ada API/controller/screen |
| Analitik Warehouse | permissions dan sebagian tabel | tidak ada route/controller |
| Notifikasi/push | `notifications`, `device_tokens` | tidak ada route/FCM service/screen di Flutter |
| Dashboard semua aktor | HomeScreen ringkasan Admin/Warehouse/Retail dan shortcut | data summary sebagian dipanggil langsung; dashboard Sales belum setara; tidak semua metrik PRD ada |

## Jumlah yang dapat dihitung

- 4 role yang didefinisikan.
- 31 deklarasi endpoint API di `routes/api.php`.
- 19 migration Laravel.
- 35 file Dart di `delcheck_flutter/lib/`; 49 file di `delcheck_laravel/app/` (termasuk controller, request, resource, service, model, enum/helper/trait/provider).
- 8 controller API, 11 model Eloquent, dan 38 tabel yang didefinisikan oleh 19 migration (termasuk tabel kerangka Laravel, Spatie, dan Sanctum).
- 9 file test PHP (Feature/Unit) dan 1 file test Flutter terinventarisasi. Test tidak dijalankan selama audit read-only.
- Modul end-to-end yang terpetakan: auth/register, verifikasi retailer, kelola akun, produk, stok, pesanan/pengiriman (6 domain; wilayah adalah data pendukung registrasi). Angka modul adalah klasifikasi audit, bukan metrik proyek yang dideklarasikan.
