# 07 — Dokumentasi API

Semua endpoint API berada di `delcheck_laravel/routes/api.php`; URL relatif di bawah berawalan `/api`. Ada 31 deklarasi route (prefix/detail/action dihitung terpisah). Header umum klien: `Accept: application/json`, `Content-Type: application/json`; endpoint terlindungi menerima `Authorization: Bearer <token Sanctum>`. Contoh URL tidak memuat base URL development.

## Endpoint dan middleware

| Method | Endpoint | Controller@method | Middleware / fungsi |
|---|---|---|---|
| GET | `/wilayah` | WilayahController@index | throttle 60/menit; daftar wilayah |
| POST | `/auth/register` | AuthController@register | throttle 10/menit; daftar Retail |
| POST | `/auth/login` | AuthController@login | throttle 10/menit; terbit token |
| POST | `/auth/logout` | AuthController@logout | auth:sanctum; hapus token aktif |
| GET | `/auth/me` | AuthController@me | auth:sanctum; profil/role/izin |
| GET | `/admin/sales` | SalesController@index | auth:sanctum + permission retailer.verifikasi |
| GET | `/admin/pendaftaran-retail` | PendaftaranRetailController@index | auth + retailer.verifikasi; search/filter/page |
| GET | `/admin/pendaftaran-retail/{retailer}` | @show | auth + retailer.verifikasi; detail |
| POST | `/admin/pendaftaran-retail/{retailer}/setujui` | @setujui | auth + retailer.verifikasi |
| POST | `/admin/pendaftaran-retail/{retailer}/tolak` | @tolak | auth + retailer.verifikasi |
| GET | `/admin/pengguna` | PenggunaController@index | auth + pengguna.kelola |
| POST | `/admin/pengguna/{user}/aktifkan` | @aktifkan | auth + pengguna.kelola |
| POST | `/admin/pengguna/{user}/nonaktifkan` | @nonaktifkan | auth + pengguna.kelola |
| GET | `/produk`, `/produk/{produk}` | ProdukController@index/show | auth + produk.lihat |
| POST | `/produk` | ProdukController@store | auth + produk.kelola |
| PUT | `/produk/{produk}` | ProdukController@update | auth + produk.kelola |
| DELETE | `/produk/{produk}` | ProdukController@destroy | auth + produk.kelola |
| GET | `/stok`, `/stok/{produk}`, `/stok/{produk}/mutasi` | StokController@index/show/riwayat | auth + stok.kelola |
| POST | `/stok/{produk}/mutasi` | StokController@ubah | auth + stok.kelola |
| GET | `/pesanan`, `/pesanan/{pesanan}` | PesananController@index/show | auth + salah satu permission melihat pesanan |
| POST | `/pesanan` | PesananController@store | auth + pesanan.buat |
| POST | `/pesanan/{pesanan}/batalkan` | @batalkan | auth + pesanan.buat |
| POST | `/pesanan/{pesanan}/terima` | @terima | auth + pesanan.terima |
| POST | `/pesanan/{pesanan}/setujui`, `/tolak` | @setujui/@tolak | auth + pesanan.konfirmasi |
| POST | `/pesanan/{pesanan}/proses` | @proses | auth + pesanan.proses |
| POST | `/pesanan/{pesanan}/kirim` | @kirim | auth + pengiriman.perbarui |

## Parameter, validasi dan response kontrak

- `GET /wilayah`: optional `tingkat` (provinsi/kota/kecamatan), `parent_id` integer, `q` string max100. Sukses `data` adalah array resource wilayah, urut nama, limit 500.
- `POST /auth/register`: `name`, email atau `phone`, `password`, `nama_toko`, alamat; opsional `nama_pemilik`, `wilayah_id`. Sukses HTTP201 dan UserResource. Password min8, huruf+angka; identifier unik setelah normalisasi.
- `POST /auth/login`: backend field yang diterima adalah `email` atau `phone`, `password`, opsional `device_name`; tidak boleh kedua identifier sekaligus. Sukses `{success,message,data:{token,token_type,user}}`.
- Retailer list: `status` enum menunggu/disetujui/ditolak, `q`, `per_page` 1–50; controller secara default `menunggu`; pencarian nama toko/kode/pemilik/telepon/email. Response paged `data.items/meta`.
- Setujui: optional `sales_id` harus user Sales aktif. Flutter saat ini tidak mengirim assignment. Tolak: `{alasan}` wajib max500. Konflik status bisnis dapat 409.
- Pengguna list: `q`, `role` enum, `aktif` boolean, `per_page` 1–50; aktifkan/nonaktifkan tanpa body. Rule bisnis menghasilkan 403/409.
- Produk list: `q`, `status=aktif|nonaktif`, `per_page`; user tanpa kelola selalu dibatasi produk aktif. `ProdukRequest` memvalidasi kode uppercase-pattern unik, nama, satuan, harga, kategori opsional.
- Stok list: `q`, optional `status=menipis`, `per_page`; mutasi body `tipe=masuk|keluar`, `jumlah` 1–1,000,000, alasan wajib untuk keluar.
- Pesanan list: `status` comma-separated enum, `q`, `per_page`; buat body `items:[{produk_id,qty}]`, optional catatan; aksi tolak/batal alasan wajib; kirim tanggal_kirim default hari ini, estimasi tanggal tidak sebelum kirim, nomor surat jalan/catatan optional.

Error: 401 token/sesi, 403 permission/akun, 404 resource/cakupan, 409 konflik bisnis, 422 validasi, 429 rate limit, 5xx server. Bentuk error tidak sepenuhnya seragam karena FormRequest/exception Laravel vs `ApiException`; klien mengakomodasi `message` atau `pesan`, `kode`, `errors`.

**Contoh struktur yang terbukti dari `ApiResponse`** (nilai data disingkat secara struktural, bukan data live):

```json
{"success":true,"message":"Berhasil.","data":{"items":["...resource..."],"meta":{"halaman":1,"per_halaman":15,"total":0,"halaman_terakhir":1}}}
```

Tidak ada URL base produksi, response live, atau credential yang dibaca; contoh payload di atas hanya mewakili wrapper yang benar-benar dibangun trait.
