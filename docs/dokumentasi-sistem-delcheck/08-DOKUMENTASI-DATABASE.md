# 08 — Dokumentasi Database

## Batas klaim

Migration mendefinisikan schema yang dimaksudkan; tidak membuktikan migration sudah diterapkan. `config/database.php` default ke SQLite jika env tidak menentukan lain; README menyebut MySQL utama yang direncanakan. **Database aktual, jumlah row, driver aktif, serta status migration tidak diperiksa.** Detail field dapat dilihat langsung di `delcheck_laravel/database/migrations/` sebagaimana tabel ringkas berikut.

## Entitas aplikasi dan peran kolom

| Tabel | Kolom utama (seluruh tabel juga memakai timestamp kecuali disebut lain) | Key/relasi penting |
|---|---|---|
| `users` | name, email?, phone?, password, is_active=true, email_verified_at?, last_login_at?, remember_token, deleted_at? | PK id; email/phone unique nullable |
| `retailers` | user_id?, wilayah_id?, kode, nama_toko, nama_pemilik?, alamat, telepon?, email?, latitude?/longitude?, is_active=true, status_verifikasi=menunggu, diverifikasi_oleh?, diverifikasi_at?, alasan_ditolak?, deleted_at? | user unique FK, wilayah/admin verifier FK; index nama/status |
| `wilayah` | parent_id?, kode, nama, tingkat=kota | parent FK self; kode unique |
| `sales_assignments` | sales_id, retailer_id, ditugaskan_oleh?, mulai?, selesai?, is_active=true | FK users/retailers; unique sales+retailer |
| `kategori_produk` | nama, slug | slug unique |
| `produk` | kategori_id?, kode, nama, deskripsi?, satuan, harga decimal(15,2), stok_minimum unsigned default0, foto?, is_active=true, deleted_at? | kategori FK; kode unique; index nama |
| `harga_produk` | produk_id, retailer_id?, harga, berlaku_mulai, berlaku_sampai? | FK produk/retailer; index produk+retailer+tanggal |
| `stok_produk` | produk_id unique, jumlah unsigned default0 | satu-ke-satu produk |
| `mutasi_stok` | produk_id, tipe, jumlah signed, stok_sebelum/sesudah unsigned, alasan?, referensi morph?, dibuat_oleh? | index produk+created_at |
| `pesanan` | nomor, retailer_id, sales_id?, sumber, dibuat_oleh, status default menunggu_konfirmasi_sales, total decimal, catatan?, kolom aktor/waktu transisi, alasan tolak/batal? | indeks status+date, retailer+status, sales+status |
| `item_pesanan` | pesanan_id, produk_id, nama_produk, satuan, harga, qty unsigned, subtotal | detail order; cascade header delete; snapshot deskripsi/harga |
| `pengiriman` | pesanan_id, nomor_surat_jalan?, status, tanggal_kirim, estimasi_tiba?, diterima_at?, catatan?, diperbarui_oleh? | satu order dapat banyak pengiriman menurut migration |
| `laporan_barang` | nomor, pesanan_id, retailer_id, dibuat_oleh, jenis_masalah, kategori_penyebab?, deskripsi?, status, ditinjau_oleh?/at? | indeks retailer/status, status/date |
| `item_laporan` | laporan_id, item_pesanan_id, produk_id, batch?, qty | detail barang laporan |
| `klaim` | laporan_id unique, keputusan?, alasan?, kompensasi_jenis/nilai?, diputuskan_oleh?/at? | satu klaim per laporan |
| `foto_bukti` | fotoable morph, path, nama_asli?, mime?, ukuran?, diunggah_oleh? | polymorphic |
| `retur` | nomor, pesanan_id, laporan_id?, retailer_id, diajukan_oleh, alasan, status, aktor/waktu, jadwal jemput?, bukti?, tindak_lanjut? | indeks retailer/status, status/date |
| `item_retur` | retur_id, item_pesanan_id, produk_id, qty | detail retur |
| `ulasan` | retailer_id, user_id, pesanan_id?, rating tinyint, komentar? | rating/date index |
| `jadwal_kunjungan` | sales_id, retailer_id, tanggal_kunjungan, minggu_mulai, status, asal_jadwal, mulai/selesai?, checkin lat/lng?, alasan_terlewat?, dijadwalkan_ulang_dari? | indeks Sales+tanggal dan Sales+minggu |
| `catatan_kunjungan` | kunjungan_id, catatan?, tindak_lanjut?, pesanan_id? | FK kunjungan; cascade |
| `target_penjualan` | sales_id, periode mulai/selesai, target_nilai | index sales+periode |
| `notifications` | UUID id, type, notifiable morph, data, read_at? | Laravel notification table |
| `device_tokens` | user_id, token unique, platform?, last_used_at? | FK user cascade |
| `audit_logs` | auditable morph, user_id?, aksi, status_dari/ke?, alasan?, meta JSON? | append only di model; index created_at |
| `roles`, `permissions`, pivots | name, guard_name, timestamp; model morph IDs dan pivot role/permission | didefinisikan migration Spatie; teams=false config |
| framework tables | `password_reset_tokens`, `sessions`, `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `personal_access_tokens` | tabel pendukung Laravel/Sanctum |

`?` menandai nullable menurut migration. Tabel kerangka Laravel mempunyai kolom spesifik di migration standar; rincian persis dapat dibaca dari file migration standar yang disebut pada dokumen 09.

## Kamus kolom lebih rinci dari migration

Notasi: `id` = big integer auto-increment primary key; `FK` = foreignId; `?` = nullable; `U` = unique; `IDX` = index. `timestamps` berarti `created_at` dan `updated_at` timestamp nullable/default framework. Semua kolom yang tidak diberi `?` pada daftar berikut dibuat non-null kecuali helper migration menyatakan lain.

| Tabel | Kolom dan tipe migration (termasuk null/default penting) |
|---|---|
| `users` | `id`; `name` string; `email` string? U; `phone` string(30)? U; `email_verified_at` timestamp?; `password` string; `is_active` boolean default true; `last_login_at` timestamp?; `remember_token` string?; timestamps; `deleted_at` soft-delete timestamp? |
| `password_reset_tokens` | `email` string PK; `token` string; `created_at` timestamp? |
| `sessions` | `id` string PK; `user_id` FK? IDX (migration tidak memakai `constrained`); `ip_address` string(45)?; `user_agent` text?; `payload` longText; `last_activity` integer IDX |
| `cache` / `cache_locks` | `cache`: `key` string PK, `value` mediumText, `expiration` integer. `cache_locks`: `key` string PK, `owner` string, `expiration` integer |
| `jobs` | `id`; `queue` string IDX; `payload` longText; `attempts` unsignedTinyInteger; `reserved_at` unsignedInteger?; `available_at`, `created_at` unsignedInteger |
| `job_batches` | `id` string PK; `name` string; `total_jobs`, `pending_jobs`, `failed_jobs` integer; `failed_job_ids` longText; `options` mediumText?; `cancelled_at` integer?; `created_at` integer; `finished_at` integer? |
| `failed_jobs` | `id`; `uuid` string U; `connection`, `queue` text; `payload`, `exception` longText; `failed_at` timestamp default current |
| `wilayah` | `id`; `parent_id` FK? self, nullOnDelete; `kode` string(20) U; `nama` string; `tingkat` string(20) default `kota`; timestamps |
| `retailers` | `id`; `user_id` FK? U → users, nullOnDelete; `wilayah_id` FK? → wilayah, nullOnDelete; `kode` string(30) U; `nama_toko` string; `nama_pemilik` string?; `alamat` text; `telepon` string(30)?; `email` string?; `latitude`,`longitude` decimal(10,7)?; `is_active` boolean default true; `status_verifikasi` string(20) default `menunggu`; `diverifikasi_oleh` FK? users nullOnDelete; `diverifikasi_at` timestamp?; `alasan_ditolak` text?; timestamps, soft delete; IDX nama_toko/status_verifikasi |
| `sales_assignments` | `id`; `sales_id` FK users cascade; `retailer_id` FK retailers cascade; `ditugaskan_oleh` FK? users nullOnDelete; `mulai`,`selesai` date?; `is_active` boolean default true; timestamps; U(sales_id,retailer_id) |
| `kategori_produk` | `id`; `nama` string; `slug` string U; timestamps |
| `produk` | `id`; `kategori_id` FK? kategori_produk nullOnDelete; `kode` string(40) U; `nama` string; `deskripsi` text?; `satuan` string(20); `harga` decimal(15,2); `stok_minimum` unsignedInteger default 0; `foto` string?; `is_active` boolean default true; timestamps, soft delete; IDX nama |
| `harga_produk` | `id`; `produk_id` FK produk cascade; `retailer_id` FK? retailers cascade; `harga` decimal(15,2); `berlaku_mulai` date; `berlaku_sampai` date?; timestamps; IDX(produk_id,retailer_id,berlaku_mulai) |
| `stok_produk` | `id`; `produk_id` FK U produk cascade; `jumlah` unsignedInteger default 0; timestamps |
| `mutasi_stok` | `id`; `produk_id` FK produk; `tipe` string(20); `jumlah` integer signed; `stok_sebelum`,`stok_sesudah` unsignedInteger; `alasan` string?; nullable morph `referensi_type`,`referensi_id`; `dibuat_oleh` FK? users nullOnDelete; timestamps; IDX(produk_id,created_at) |
| `pesanan` | `id`; `nomor` string(40) U; `retailer_id` FK retailers; `sales_id` FK? users nullOnDelete; `sumber` string(10); `dibuat_oleh` FK users; `status` string(30) default `menunggu_konfirmasi_sales`; `total` decimal(15,2) default 0; `catatan` text?; `dikonfirmasi_oleh` FK? users nullOnDelete; `dikonfirmasi_at` timestamp?; `alasan_ditolak` text?; `diproses_oleh` FK? users nullOnDelete; `diproses_at`,`dikirim_at` timestamp?; `diterima_oleh` FK? users nullOnDelete; `diterima_at`,`selesai_at` timestamp?; `dibatalkan_oleh` FK? users nullOnDelete; `dibatalkan_at` timestamp?; `alasan_batal` text?; timestamps; IDX(status,created_at), IDX(retailer_id,status), IDX(sales_id,status) |
| `item_pesanan` | `id`; `pesanan_id` FK pesanan cascade; `produk_id` FK produk; `nama_produk` string; `satuan` string(20); `harga` decimal(15,2); `qty` unsignedInteger; `subtotal` decimal(15,2); timestamps; IDX pesanan_id |
| `pengiriman` | `id`; `pesanan_id` FK pesanan cascade; `nomor_surat_jalan` string(40)?; `status` string(20) default `dikirim`; `tanggal_kirim` date; `estimasi_tiba` date?; `diterima_at` timestamp?; `catatan` text?; `diperbarui_oleh` FK? users nullOnDelete; timestamps; IDX(pesanan_id,status) |
| `laporan_barang` | `id`; `nomor` string(40) U; `pesanan_id` FK pesanan; `retailer_id` FK retailers; `dibuat_oleh` FK users; `jenis_masalah` string(30); `kategori_penyebab` string(50)?; `deskripsi` text?; `status` string(30) default `dibuat`; `ditinjau_oleh` FK? users nullOnDelete; `ditinjau_at` timestamp?; timestamps; IDX(retailer_id,status),(status,created_at) |
| `item_laporan` | `id`; `laporan_id` FK laporan_barang cascade; `item_pesanan_id` FK item_pesanan; `produk_id` FK produk; `batch` string(50)?; `qty` unsignedInteger; timestamps |
| `klaim` | `id`; `laporan_id` FK U laporan_barang cascade; `keputusan` string(20)?; `alasan` text?; `kompensasi_jenis` string(30)?; `kompensasi_nilai` decimal(15,2)?; `diputuskan_oleh` FK? users nullOnDelete; `diputuskan_at` timestamp?; timestamps |
| `foto_bukti` | `id`; morph `fotoable_type`,`fotoable_id` (index); `path` string; `nama_asli` string?; `mime` string(50)?; `ukuran` unsignedInteger?; `diunggah_oleh` FK? users nullOnDelete; timestamps |
| `retur` | `id`; `nomor` string(40) U; `pesanan_id` FK pesanan; `laporan_id` FK? laporan_barang nullOnDelete; `retailer_id` FK retailers; `diajukan_oleh` FK users; `alasan` text; `status` string(30) default `diajukan`; `dikonfirmasi_oleh` FK? users nullOnDelete; `dikonfirmasi_at` timestamp?; `alasan_ditolak` text?; `jadwal_jemput` dateTime?; `dijemput_at` timestamp?; `bukti_jemput` string?; `diterima_gudang_at` timestamp?; `tindak_lanjut` string(30)?; `selesai_at` timestamp?; timestamps; IDX(retailer_id,status),(status,created_at) |
| `item_retur` | `id`; `retur_id` FK retur cascade; `item_pesanan_id` FK item_pesanan; `produk_id` FK produk; `qty` unsignedInteger; timestamps |
| `ulasan` | `id`; `retailer_id` FK retailers cascade; `user_id` FK users; `pesanan_id` FK? pesanan nullOnDelete; `rating` unsignedTinyInteger; `komentar` text?; timestamps; IDX(rating,created_at) |
| `jadwal_kunjungan` | `id`; `sales_id` FK users cascade; `retailer_id` FK retailers; `tanggal_kunjungan`,`minggu_mulai` date; `status` string(20) default `dijadwalkan`; `asal_jadwal` string(20) default `disusun_sendiri`; `mulai_at`,`selesai_at` timestamp?; `checkin_latitude`,`checkin_longitude` decimal(10,7)?; `alasan_terlewat` string?; `dijadwalkan_ulang_dari` FK? self nullOnDelete; timestamps; IDX(sales_id,tanggal_kunjungan),(sales_id,minggu_mulai) |
| `catatan_kunjungan` | `id`; `kunjungan_id` FK jadwal_kunjungan cascade; `catatan`,`tindak_lanjut` text?; `pesanan_id` FK? pesanan nullOnDelete; timestamps |
| `target_penjualan` | `id`; `sales_id` FK users cascade; `periode_mulai`,`periode_selesai` date; `target_nilai` decimal(15,2); timestamps; IDX(sales_id,periode_mulai) |
| `notifications` | `id` UUID PK; `type` string; morph `notifiable_type`,`notifiable_id` indexed; `data` text; `read_at` timestamp?; timestamps |
| `device_tokens` | `id`; `user_id` FK users cascade; `token` string(512) U; `platform` string(10)?; `last_used_at` timestamp?; timestamps |
| `audit_logs` | `id`; morph `auditable_type`,`auditable_id` indexed; `user_id` FK? users nullOnDelete; `aksi` string(40); `status_dari`,`status_ke` string(30)?; `alasan` text?; `meta` JSON?; `created_at` timestamp current; tidak ada updated_at |
| Permission tables | `permissions`: id, name string, guard_name string, timestamps, unique(name,guard_name). `roles`: id,name,guard_name,timestamps, unique(name,guard_name) karena teams false. Pivot model_has_permissions/model_has_roles menggunakan permission_id/role_id, model_type, model_id, composite primary + FK cascade. `role_has_permissions` composite PK role_id+permission_id, kedua FK cascade. Nama tabel dari package config |
| Sanctum `personal_access_tokens` | `id`; morph `tokenable_type`,`tokenable_id` indexed; `name` text; `token` string(64) U; `abilities` text?; `last_used_at`,`expires_at` timestamp? (expires indexed); timestamps |

## Relasi Eloquent yang benar-benar dibuat

- `User hasOne Retailer`; Retailer belongsTo user, wilayah, diverifikasiOleh; Retailer belongsToMany User melalui `sales_assignments` (hanya pivot aktif), dengan dates dan timestamps.
- `Wilayah belongsTo parent` dan `hasMany children`.
- `Produk hasOne StokProduk`; `scopeDenganStok()` LEFT JOIN untuk stok dengan COALESCE 0.
- `Pesanan belongsTo Retailer, sales(User), pembuat(User); hasMany items, pengiriman`.
- `ItemPesanan belongsTo Pesanan dan Produk`; `Pengiriman belongsTo Pesanan`.
- `SalesAssignment belongsTo sales dan retailer`; `MutasiStok belongsTo produk/pembuat dan morphTo referensi`.
- `AuditLog` menggunakan morph key tetapi tidak menyatakan relasi method `morphTo` eksplisit dalam model.

Relasi tabel laporan/retur/klaim/kunjungan tidak semuanya punya model Eloquent di repo; migration FK menjadi bukti relasi schema, bukan API yang berjalan.

## Transaksi, query, dan indeks

`PesananService::kirim` mengunci pesanan lalu stok tiap produk dan mengubah stok/log dalam satu transaksi. `StokService::ubah` memakai `firstOrCreate`, `lockForUpdate`, update saldo, create mutasi. `Produk::scopeDenganStok` menghindari query per produk (komentar model). Filter paginasi memanfaatkan indeks yang didefinisikan migration. Padanan SQL tidak dituliskan karena query builder menggabungkan eager-load, conditional clauses dan paginator; query SQL konkret bergantung DB driver.
