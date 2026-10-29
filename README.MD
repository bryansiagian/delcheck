# DELCHECK

DELCHECK adalah aplikasi untuk mendukung pengelolaan pemesanan, penjualan, dan persediaan barang. Aplikasi ini dikembangkan menggunakan **Flutter** sebagai frontend mobile dan **Laravel** sebagai backend API.

Sistem dirancang untuk membantu proses pemesanan barang oleh pelanggan retail, konfirmasi pesanan oleh bagian sales, serta pengelolaan persediaan dan pengiriman oleh bagian gudang dan admin.

## Fitur Utama

- Autentikasi dan pengelolaan akun pengguna.
- Pemesanan barang oleh pengguna retail.
- Konfirmasi dan pengelolaan pesanan oleh sales.
- Pengelolaan barang dan persediaan gudang.
- Pencatatan informasi pengiriman dan pengemudi.
- Pengelolaan data oleh admin.
- Pengujian backend menggunakan Laravel testing.

## Hak Akses Pengguna

DELCHECK memiliki empat jenis peran pengguna.

| Role | Tanggung Jawab |
|---|---|
| Admin | Memiliki hak akses tertinggi, mengelola akun dan data seluruh pengguna, serta menjalankan tugas sales dan gudang. |
| Warehouse | Mengelola persediaan barang dan membantu proses persiapan pengiriman pesanan. |
| Sales | Memeriksa dan mengonfirmasi pesanan yang masuk dari retail. |
| Retail | Melihat barang yang tersedia dan membuat pesanan. |

Hak akses setiap pengguna disesuaikan dengan perannya di dalam sistem.

## Alur Bisnis

1. **Retail membuat pesanan.** Pengguna retail memilih barang dan mengirimkan pesanan melalui aplikasi.
2. **Sales mengonfirmasi pesanan.** Bagian sales memeriksa pesanan sebelum diproses lebih lanjut.
3. **Persiapan pengiriman.** Admin atau warehouse menyiapkan barang yang akan dikirim.
4. **Pencatatan pengiriman.** Informasi pengiriman dan pengemudi dimasukkan secara manual ke sistem oleh admin atau warehouse.
5. **Pengelolaan data.** Admin dapat memantau dan mengelola data yang diperlukan sesuai kewenangannya.

Catatan: Proses penentuan pengemudi dan pelaksanaan pengiriman dilakukan di luar sistem. DELCHECK digunakan untuk mencatat informasi pengiriman tersebut.

## Teknologi yang Digunakan

### Frontend
- Flutter
- Dart

### Backend
- Laravel
- PHP
- REST API

### Database
- MySQL sebagai database utama yang direncanakan.
- PostgreSQL dapat digunakan sebagai alternatif dengan penyesuaian konfigurasi dan pengujian kompatibilitas.

### Testing
- Laravel PHPUnit/Pest sesuai konfigurasi proyek.
- Flutter testing.

## Struktur Proyek

```text
delcheck/
├── delcheck_flutter/
│   ├── lib/
│   │   ├── core/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── test/
│   └── pubspec.yaml
│
├── delcheck_laravel/
│   ├── app/
│   │   ├── Enums/
│   │   ├── Exceptions/
│   │   ├── Http/
│   │   ├── Models/
│   │   ├── Providers/
│   │   ├── Services/
│   │   ├── Support/
│   │   └── Traits/
│   ├── database/
│   │   ├── factories/
│   │   ├── migrations/
│   │   └── seeders/
│   ├── routes/
│   │   ├── api.php
│   │   ├── console.php
│   │   └── web.php
│   ├── tests/
│   │   ├── Feature/
│   │   └── Unit/
│   ├── .env.example
│   ├── artisan
│   ├── composer.json
│   └── phpunit.xml
│
├── PRD.MD
└── README.md
```

## Persyaratan Sistem

Pastikan perangkat pengembangan telah memiliki:

- Git
- Flutter SDK dan Dart SDK
- Android Studio atau perangkat Android untuk menjalankan aplikasi Flutter
- PHP dengan versi yang sesuai dengan kebutuhan proyek Laravel
- Composer
- MySQL atau PostgreSQL
- Ekstensi PHP yang diperlukan oleh Laravel dan driver database yang digunakan

Periksa instalasi dengan perintah berikut:

```bash
git --version
flutter --version
dart --version
php --version
composer --version
```

## Instalasi dan Menjalankan Backend Laravel

### 1. Masuk ke direktori backend

Jalankan perintah dari direktori utama proyek:

```bash
cd delcheck_laravel
```

### 2. Instal dependensi

```bash
composer install
```

### 3. Siapkan file environment

Salin `.env.example` menjadi `.env`.

Di Windows Command Prompt:

```cmd
copy .env.example .env
```

Di PowerShell:

```powershell
Copy-Item .env.example .env
```

### 4. Buat application key

```bash
php artisan key:generate
```

### 5. Konfigurasi database

Buka file `.env`, kemudian sesuaikan konfigurasi database.

Contoh untuk MySQL:

```dotenv
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=delcheck
DB_USERNAME=root
DB_PASSWORD=
```

Buat database `delcheck` terlebih dahulu melalui MySQL atau alat pengelola database yang digunakan.

Jika menggunakan PostgreSQL, sesuaikan konfigurasi menjadi seperti berikut:

```dotenv
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=delcheck
DB_USERNAME=postgres
DB_PASSWORD=password_database
```

Ganti nilai username dan password sesuai konfigurasi lokal. Pastikan ekstensi PHP untuk driver database yang digunakan sudah aktif.

**Catatan:** PostgreSQL tidak otomatis kompatibel dengan seluruh migration, query, tipe data, atau fungsi khusus MySQL. Periksa dan uji seluruh bagian tersebut sebelum menggunakan PostgreSQL.

### 6. Jalankan migration

Setelah database dibuat dan konfigurasi benar:

```bash
php artisan migrate
```

Jika proyek membutuhkan data awal dan seeder telah disiapkan:

```bash
php artisan db:seed
```

Jalankan seeder hanya jika sesuai dengan kebutuhan lingkungan pengembangan. Periksa implementasi seeder sebelum menjalankannya.

### 7. Jalankan backend

```bash
php artisan serve
```

Secara default, Laravel dapat diakses melalui:

```text
http://127.0.0.1:8000
```

Alamat tersebut merupakan alamat server lokal untuk pengembangan. Endpoint API yang tersedia mengikuti definisi pada file `routes/api.php`.

## Instalasi dan Menjalankan Frontend Flutter

### 1. Buka terminal baru

Dari direktori utama proyek:

```bash
cd delcheck_flutter
```

### 2. Instal dependensi

```bash
flutter pub get
```

### 3. Periksa perangkat

```bash
flutter devices
```

Pastikan emulator atau perangkat Android tersedia.

### 4. Jalankan aplikasi

```bash
flutter run
```

Jika terdapat beberapa perangkat, tentukan perangkat tujuan sesuai ID yang ditampilkan oleh perintah `flutter devices`.

### 5. Konfigurasi alamat backend

Pastikan alamat API yang digunakan aplikasi Flutter sesuai dengan lokasi backend Laravel.

Untuk emulator Android, alamat `127.0.0.1` biasanya merujuk ke emulator itu sendiri, bukan komputer host. Pada Android Emulator, alamat host biasanya dapat dijangkau melalui:

```text
http://10.0.2.2:8000
```

Jika menggunakan perangkat fisik, gunakan alamat IP lokal komputer yang menjalankan Laravel dan pastikan keduanya berada di jaringan yang dapat saling terhubung.

Sesuaikan konfigurasi dengan implementasi API pada proyek. Jangan menggunakan alamat localhost komputer secara langsung pada perangkat fisik.

## Pengujian

### Backend Laravel

Masuk ke direktori backend:

```bash
cd delcheck_laravel
```

Jalankan seluruh pengujian:

```bash
php artisan test
```

Untuk menjalankan pengujian pada direktori Feature:

```bash
php artisan test tests/Feature
```

Untuk menjalankan pengujian pada direktori Unit:

```bash
php artisan test tests/Unit
```

Pastikan konfigurasi database pengujian sesuai dengan kebutuhan test. Gunakan database khusus pengujian agar data pengembangan tidak terpengaruh.

Jika pengujian membutuhkan konfigurasi environment tersendiri, periksa `phpunit.xml` dan konfigurasi test yang digunakan.

### Frontend Flutter

Masuk ke direktori frontend:

```bash
cd delcheck_flutter
```

Jalankan seluruh pengujian:

```bash
flutter test
```

Untuk menjalankan pemeriksaan analisis kode:

```bash
flutter analyze
```

## Keamanan dan Konfigurasi

- Jangan mengunggah file `.env` ke repositori Git.
- Jangan menyimpan password, token, atau kredensial database langsung di source code.
- Gunakan `.env.example` untuk mendokumentasikan variabel environment yang diperlukan tanpa memasukkan rahasia.
- Pastikan endpoint yang membutuhkan autentikasi memiliki mekanisme pemeriksaan hak akses.
- Pastikan admin, warehouse, sales, dan retail hanya dapat melakukan tindakan yang sesuai dengan kewenangannya.
- Gunakan konfigurasi yang berbeda untuk pengembangan, pengujian, dan produksi.
- Hindari menjalankan migration atau seeder yang berpotensi menghapus atau mengubah data penting tanpa pemeriksaan terlebih dahulu.

## Troubleshooting

### Composer gagal menginstal dependensi

Periksa versi PHP, ekstensi PHP yang diperlukan, serta kecocokan versi dependensi dengan `composer.json`.

### Database tidak dapat terhubung

Periksa apakah server database sedang berjalan, database sudah dibuat, konfigurasi `.env` benar, dan driver PHP yang sesuai telah aktif.

Setelah mengubah konfigurasi, bersihkan cache konfigurasi bila diperlukan:

```bash
php artisan config:clear
```

### Migration gagal

Periksa pesan error migration, tipe data, constraint, dan kompatibilitas database. Pastikan database yang digunakan sesuai dengan target pengembangan.

### Flutter tidak dapat mengakses API

Pastikan backend Laravel berjalan, alamat API benar, perangkat dapat menjangkau komputer host, dan konfigurasi jaringan mengizinkan koneksi.

### Pengujian gagal

Baca pesan error yang ditampilkan, periksa konfigurasi environment pengujian, database, dependensi, serta kebutuhan data awal.

## Pengembangan Lebih Lanjut

Pengembangan DELCHECK dilakukan pada dua bagian utama:

- **`delcheck_flutter/`** untuk antarmuka pengguna dan logika aplikasi mobile.
- **`delcheck_laravel/`** untuk API, aturan bisnis, autentikasi, pengolahan data, dan integrasi database.

Dokumentasi kebutuhan produk tersedia pada file `PRD.MD` di direktori utama proyek.

## Status Proyek

DELCHECK dikembangkan sebagai proyek aplikasi manajemen pemesanan, penjualan, persediaan, dan pencatatan pengiriman. Detail fitur yang sudah selesai, endpoint API, dan konfigurasi deployment mengikuti implementasi terbaru pada repositori.
