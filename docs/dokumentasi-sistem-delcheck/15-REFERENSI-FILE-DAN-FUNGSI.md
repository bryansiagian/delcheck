# 15 — Referensi File dan Fungsi

## Flutter (`delcheck_flutter/lib/`)

| File/kelompok | Class atau method penting |
|---|---|
| `main.dart` | `main`, `DelCheckApp.build`, `AuthGate.build` |
| `core/config.dart` | `AppConfig.baseUrl`, `timeout` |
| `core/api_client.dart` | `ApiException`, `ApiClient.get/post/put/delete/_send/_toException` |
| `core/format.dart` | formatter angka/tanggal yang digunakan screen |
| `providers/auth_provider.dart` | `AuthProvider.mulai/login/logout/_bersihkanSesi` |
| `services/auth_service.dart` | `AuthService.login/me/logout/_unwrap` |
| `services/register_service.dart` | `fetchWilayah`, `register`, payload + error class |
| `services/admin_service.dart` | `daftar`, `setujui`, `tolak`, `HalamanRetailer` |
| `services/pengguna_service.dart` | `daftar`, `aktifkan`, `nonaktifkan`, `_ubah` |
| `services/produk_service.dart` | `daftar`, `tambah`, `ubah`, `hapus` |
| `services/stok_service.dart` | `daftar`, `riwayat`, `ubah` |
| `services/pesanan_service.dart` | `daftar`, `detail`, `buat`, aksi status |
| `models/*.dart` | factory `fromJson` tiap entitas; field ada di dokumen 05/08 |
| `screens/admin_verifikasi_screen.dart` | `_muatAwal`, `_muatLagi`, `_gantiStatus`, `_onCari`, `_buka`, builder UI |
| `screens/admin_detail_retailer_screen.dart` | `_setujui`, `_tolak`, `_jalankan`, `_TolakDialog` |
| `screens/admin_pengguna_screen.dart` | `_muatAwal`, `_muatLagi`, `_ubahStatus`, `_item`, `_barisFilter` |
| `screens/home_screen.dart` | `_muatDataRingkasan`, `_keluar`, `_buka`, `_buildSummaryItem`, `_buildFeaturedCard`, `_buildGridCard` |
| `screens/pesanan_detail_screen.dart` | `_muat`, `_jalankan`, `_konfirmasi`, `_mintaAlasan`, transisi tiap role, `_aksiBar` |
| `screens/stok_detail_screen.dart` | `_muatRiwayat`, `_aturJumlah`, `_hitungHasilStok`, `_simpan` |
| `screens/stok_list_screen.dart` | `_muatAwal`, `_muatLagi`, `_gantiFilter`, `_onCari`, `_buka` |
| `screens/produk_list_screen.dart` | load/filter/search/open/delete; form ada di `produk_form_screen.dart` |
| `screens/pesanan_list_screen.dart` | load/filter/search/detail; memakai `CatatPengirimanBottomSheet` |
| `widgets/status_pesanan_chip.dart` | `StatusPesananChip.build` |
| `widgets/catat_pengiriman_bottom_sheet.dart` | bottom sheet input data kirim pesanan |

## Laravel (`delcheck_laravel/`)

| File/kelompok | Method/class |
|---|---|
| `routes/api.php`, `bootstrap/app.php` | deklarasi endpoint, alias permission, JSON exception |
| `app/Http/Controllers/Api/AuthController.php` | `register/login/logout/me` |
| `.../WilayahController.php` | `index` |
| `.../Admin/PendaftaranRetailController.php` | `index/show/setujui/tolak` |
| `.../Admin/PenggunaController.php` | `index/aktifkan/nonaktifkan` |
| `.../Admin/SalesController.php` | `index` |
| `.../ProdukController.php` | `index/show/store/update/destroy/dataTersaring` |
| `.../StokController.php` | `index/show/riwayat/ubah/denganStok` |
| `.../PesananController.php` | `index/show/store/batalkan/setujui/tolak/proses/kirim/terima/batasiUntuk` |
| `app/Services/AuthService.php` | `registerRetail/login/pastikanBolehLogin` |
| `.../VerifikasiRetailService.php` | `setujui/tolak/kunciDanPastikanStatus` |
| `.../PenggunaService.php` | `aktifkan/nonaktifkan` |
| `.../PesananService.php` | buat, transisi, helper lock/pemilik, eager-load constant `MUAT` |
| `.../StokService.php` | `ubah` |
| `app/Models/*.php` | Eloquent fillable/casts/relationship; daftar pada dokumen 08 |
| `app/Http/Requests/**` | validasi request; lihat detail kontrak di dokumen 07 |
| `app/Http/Resources/**` | JSON field whitelist dan nested relations |
| `app/Traits/ApiResponse.php` | `success/error/paginated` |
| `app/Exceptions/ApiException.php` | renderer error bisnis JSON |
| `app/Enums/{Peran,StatusVerifikasi,StatusPesanan}.php` | enum role/status dan label |
| `app/Support/NomorTelepon.php` | `normalisasi` digit Indonesia ke awalan 62 |
| `database/seeders/RolePermissionSeeder.php` | `peta`, `run`; definisi role-permission |
| `database/seeders/UserSeeder.php`, `WilayahSeeder.php`, `DatabaseSeeder.php` | data awal development dan orkestrasi |

## Nomor baris

Lokasi file dan nama method diprioritaskan karena line number berubah oleh format/perubahan versi. Untuk melihat nomor baris terkini gunakan pencarian editor pada nama method. Audit ini tidak menambahkan line-number claim yang berisiko tidak akurat.
