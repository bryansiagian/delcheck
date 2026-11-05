# 01 — Gambaran Umum Sistem

## Identitas sistem

**[TERBUKTI DI KODE]** README menyebut Delcheck sebagai aplikasi pengelolaan pemesanan, penjualan, persediaan dan pencatatan pengiriman. Implementasi di repo terdiri dari aplikasi Flutter di `delcheck_flutter/` dan backend Laravel di `delcheck_laravel/`. Flutter manifest menetapkan Dart SDK `^3.8.1`, paket `http`, `provider`, `flutter_secure_storage`; Composer menetapkan PHP `^8.2`, Laravel `^12.0`, Sanctum `^4.0`, dan Spatie Permission `^6.25`.

**[KESIMPULAN ANALISIS]** Alur transaksi yang benar-benar tersedia di API adalah akun Retail mendaftar → Admin memverifikasi → Retail membuat pesanan → Sales mengonfirmasi/menolak → Admin/Warehouse memproses dan mengirim → Retail mengonfirmasi penerimaan. Modul katalog produk dan stok mendukung alur ini. Peran Admin dan Warehouse berbagi sejumlah izin operasional.

## Masalah yang ditangani dan pengguna

Sistem memusatkan data toko, katalog, jumlah stok, pesanan, catatan mutasi dan pengiriman. Role yang didefinisikan dalam `app/Enums/Peran.php` serta `RolePermissionSeeder.php` adalah `retail`, `sales`, `admin`, dan `warehouse`. Tanggung jawab praktis dan pembatasannya dijelaskan di [03-role](03-ROLE-DAN-HAK-AKSES.md).

**[TERBUKTI DI KODE]** UI yang tersedia meliputi login, pendaftaran Retail, beranda, daftar/buat/detail pesanan, produk, stok, daftar verifikasi retailer, detail verifikasi, dan kelola akun. **[BELUM DAPAT DIPASTIKAN]** Beberapa izin dan tabel disiapkan untuk laporan barang, klaim, retur, ulasan, kunjungan, analitik dan notifikasi, tetapi tidak ada route/controller/API Flutter untuk semua modul tersebut dalam `routes/api.php` dan `lib/` yang diperiksa. Karena itu modul tersebut tidak boleh dianggap telah berjalan hanya karena muncul di PRD, permission seeder, atau migration.

## Status sumber kebenaran

| Jenis informasi | Bukti | Makna |
|---|---|---|
| Implementasi aktual | `lib/`, `app/`, `routes/`, `database/migrations/` | Dasar utama penjelasan perilaku sekarang |
| Kebutuhan rancangan | `PRD.MD` | Draft berisi TBC/asumsi, bukan kontrak implementasi |
| Dokumentasi proyek | `README.MD` | Petunjuk umum; perlu dibandingkan dengan source |
| Kondisi database live | Tidak diperiksa | Status migration/data aktual tidak diketahui |

## Ringkasan kualitas bukti

Kontrak endpoint, aturan validasi, transformasi resource, role dan struktur tabel dapat ditelusuri langsung di source. Pengalaman perangkat, jaringan, behavior DB engine, data yang sudah terpasang, serta konfigurasi deployment tetap **[PERLU PENGUJIAN]**. Konfigurasi koneksi database memiliki default `sqlite` di `config/database.php`, sedangkan README menyebut MySQL sebagai rencana utama dan PostgreSQL alternatif; `.env` tidak dibaca atau ditampilkan.
