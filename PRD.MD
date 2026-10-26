# PRD: Aplikasi Mobile Pendistribusian Barang

| Atribut | Nilai |
|---|---|
| Versi | 1.1 (Draft) |
| Status | Menunggu konfirmasi klien atas item bertanda **[TBC]** |
| Sumber requirement | Desain Figma klien (sidebar per aktor), Use Case Diagram "Pendistribusian Barang", dan jawaban klien (Bagian 12.1) |
| Platform target | Aplikasi mobile **[TBC: Android saja atau Android dan iOS]** |
| Bahasa antarmuka | Bahasa Indonesia |

**Konvensi dokumen**
- **[TBC]** = To Be Confirmed, butuh konfirmasi klien.
- **[ASUMSI]** = asumsi analis yang perlu divalidasi.
- ID: `UC-` use case, `FR-` kebutuhan fungsional, `BR-` aturan bisnis, `NFR-` non-fungsional.

**Riwayat revisi**

| Versi | Perubahan |
|---|---|
| 1.0 | Draf awal dari Figma dan Use Case Diagram |
| 1.1 | Menyerap jawaban klien: (1) Admin memproses pesanan dan mengubah status pengiriman menjadi *Dikirim*, (2) Retail mengonfirmasi penerimaan (*Diterima*), (3) Rute & Kunjungan, Kinerja & Insentif, dan Dashboard Beranda masuk ruang lingkup. Menambah UC-R07, UC-S06, UC-S07. Memperbarui alur, status, aturan bisnis, model data, fase rilis, dan matriks keterlacakan |

---

## 1. Ringkasan Produk

### 1.1 Latar Belakang
Proses distribusi barang antara toko (retail), sales lapangan, distributor, dan pengawas gudang membutuhkan satu platform terpadu untuk pemesanan, pemantauan pengiriman dan stok, pelaporan barang bermasalah, klaim, retur, serta pemantauan kunjungan dan kinerja penjualan. Aplikasi mobile ini menyatukan seluruh alur tersebut untuk empat aktor dengan peran berbeda.

### 1.2 Tujuan Produk
1. Mendigitalkan pemesanan barang, baik oleh Retail maupun oleh Sales atas nama toko.
2. Memberi Admin (distributor) alat untuk memproses pesanan, mengelola pengiriman dan stok.
3. Menyediakan alur pelaporan barang bermasalah, klaim, dan retur yang terlacak.
4. Memberi Warehouse alat analisis (sebaran retail, akar permasalahan, mutu kemasan, logistik retur) dan wewenang memutuskan klaim.
5. Membantu Sales merencanakan kunjungan mingguan ke toko binaan dan memantau kinerja penjualannya untuk mendukung keputusan bisnis.

### 1.3 Ruang Lingkup
**In scope**
- Autentikasi dan hak akses berbasis peran.
- 23 use case pada Use Case Diagram ditambah 3 use case dari Figma dan jawaban klien: UC-R07, UC-S06, UC-S07 (total 26, Bagian 4). **Diagram perlu diperbarui** agar memuat tiga use case tambahan.
- Dashboard Beranda per aktor, notifikasi, dan pelaporan.

**Out of scope (sementara) [ASUMSI]**
- Pembayaran online, tagihan, dan kredit/tempo.
- Integrasi ERP atau akuntansi.
- Aplikasi driver terpisah (status pengiriman diperbarui oleh Admin, lihat UC-A02).
- Pelacakan GPS kendaraan pengiriman.
- Panel web super admin.

---

## 2. Aktor

| Aktor (Diagram) | Nama di Figma | Peran |
|---|---|---|
| **Retail** | Toko / Retail | Toko pemesan barang. Membuat pesanan, mengonfirmasi penerimaan barang, melaporkan barang bermasalah, mengajukan retur |
| **Sales** | Sales | Perwakilan penjualan. Membuat pesanan untuk toko, mengonfirmasi pesanan dan retur, memantau laporan dan profil toko binaan, mengelola jadwal kunjungan mingguan, memantau kinerja penjualan |
| **Admin** | Distributor | Pengelola operasional. Memproses pesanan, memperbarui status pengiriman, mengelola stok dan produk, melihat retailer dan ulasan |
| **Warehouse** | Warehouse Administrator | Pengawas mutu dan klaim. Menganalisis data distribusi dan memutuskan klaim |

> **[TBC]** Nama final aktor: "Admin" atau "Distributor", "Warehouse" atau "Warehouse Administrator". Dokumen ini memakai nama pada use case diagram.

### 2.1 Matriks Hak Akses Ringkas

| Fungsi | Retail | Sales | Admin | Warehouse |
|---|:-:|:-:|:-:|:-:|
| Membuat pesanan | ✔ | ✔ | | |
| Mengonfirmasi pesanan | | ✔ | | |
| Memproses pesanan | | | ✔ | |
| Melihat pesanan | ✔ (milik sendiri) | ✔ (toko binaan) | ✔ (semua) | |
| Memperbarui status pengiriman (*Dikirim*) | | | ✔ | |
| Memantau status pesanan dan pengiriman | ✔ (milik sendiri) | ✔ (toko binaan) | ✔ (semua) | |
| Mengonfirmasi penerimaan (*Diterima*) | ✔ (milik sendiri) | | | |
| Kelola produk dan stok | | | ✔ | |
| Melaporkan barang | ✔ | | | |
| Mengajukan retur | ✔ | | | |
| Konfirmasi retur | | ✔ | | |
| Melihat laporan retail | | ✔ (toko binaan) | | ✔ (semua) |
| Memutuskan klaim | | | | ✔ |
| Analitik (sebaran, akar masalah, mutu, logistik retur) | | | | ✔ |
| Jadwal Rute & Kunjungan | | ✔ (milik sendiri) | | |
| Kinerja dan analisis penjualan | | ✔ (milik sendiri) | | |
| Melihat daftar retailer | | | ✔ | |
| Melihat ulasan | | | ✔ | |
| Melihat profil toko | ✔ (sendiri) | ✔ (toko binaan) | | |
| Dashboard Beranda | ✔ | ✔ | ✔ | ✔ |

---

## 3. Alur Bisnis

### Alur A: Pesanan dari Retail
1. Retail membuat pesanan (UC-R01).
2. Pesanan masuk ke Sales terkait dan menunggu konfirmasi.
3. Sales mengonfirmasi atau menolak (UC-S02).
4. Pesanan terkonfirmasi tampil bagi Admin, lalu Admin memprosesnya (UC-A01) dan status menjadi *Diproses*.
5. Admin memperbarui status menjadi *Dikirim* (UC-A02). Stok berkurang (UC-A03, BR-07).
6. Retail memantau status (UC-R02). Setelah barang sampai, Retail mengonfirmasi penerimaan dan status menjadi *Diterima* (UC-R07).
7. Bila barang bermasalah, lanjut ke Alur C.

### Alur B: Pesanan dibuat Sales
1. Sales memilih toko binaan dan membuat pesanan (UC-S01).
2. **[TBC]** Apakah perlu konfirmasi dari Retail atau langsung terkonfirmasi.
3. Lanjut seperti Alur A langkah 4 sampai 7.

### Alur C: Barang bermasalah, klaim, dan retur
1. Retail melaporkan barang bermasalah dengan bukti foto (UC-R04).
2. Laporan terlihat oleh Sales (UC-S04) dan Warehouse (UC-W06).
3. Warehouse meninjau dan memutuskan klaim (UC-W03).
4. Jika diperlukan retur, Retail mengajukan retur (UC-R05).
5. Sales mengonfirmasi retur dan penjemputan (UC-S03).
6. Warehouse memantau logistik retur (UC-W05).
7. Data laporan, klaim, dan retur menjadi bahan analisis akar permasalahan dan mutu kemasan (UC-W02, UC-W04).

> **[TBC]** Urutan dan keterkaitan Melaporkan Barang, Klaim, dan Retur Barang (apakah retur selalu didahului klaim yang disetujui, atau dapat diajukan langsung).

### Alur D: Ulasan
Retail memberi ulasan atas layanan atau produk → Admin melihat ulasan (UC-A06). **[TBC]** Use case "Memberi Ulasan" belum ada pada diagram.

### Alur E: Kunjungan dan kinerja Sales
1. Sales melihat jadwal kunjungan mingguan ke toko binaan. Hari kunjungan tidak tetap dan dapat berbeda tiap minggu (UC-S06).
2. Saat mengunjungi toko, Sales dapat membuka profil toko (UC-S05), membuat pesanan (UC-S01), dan mencatat hasil kunjungan.
3. Sales memantau kinerja penjualannya melalui grafik dan angka (UC-S07).

---

## 4. Spesifikasi Use Case

### 4.1 Fungsi Umum (di luar diagram, wajib ada)

| ID | Kebutuhan |
|---|---|
| FR-COM-01 | Login, logout, ubah kata sandi, dan reset kata sandi |
| FR-COM-02 | Kontrol akses berbasis peran (RBAC): tiap aktor hanya melihat menu dan data miliknya, diterapkan di sisi server |
| FR-COM-03 | Dashboard Beranda per aktor, berisi ringkasan dan pintasan ke tugas yang menunggu tindakan (isi per aktor di Bagian 4.6). Metrik final **[TBC]** |
| FR-COM-04 | Notifikasi push dan in-app untuk perubahan status pesanan, pengiriman, laporan, klaim, retur, dan pengingat kunjungan |
| FR-COM-05 | Pencarian, filter, dan pagination pada setiap daftar |
| FR-COM-06 | Audit trail untuk setiap perubahan status (pelaku, waktu, alasan) |
| FR-COM-07 | Manajemen akun pengguna dan penugasan Sales ke toko **[TBC: siapa yang berwenang dan lewat apa]** |

---

### 4.2 Aktor: Retail

#### UC-R01 Membuat Pesanan *(dipakai bersama Sales, lihat UC-S01)*
- **Menu Figma:** Buat Pesanan
- **Prasyarat:** Retail sudah login dan akun aktif.
- **Alur utama:**
  1. Retail membuka daftar produk aktif beserta harga.
  2. Retail menambahkan produk dan kuantitas ke keranjang.
  3. Sistem menampilkan ringkasan item dan total harga.
  4. Retail mengirim pesanan.
  5. Sistem membuat pesanan berstatus *Menunggu Konfirmasi Sales* dan mengirim notifikasi ke Sales terkait.
- **Alur alternatif:** Produk atau stok tidak tersedia → sistem menolak penambahan dan menampilkan pesan. Keranjang kosong → pengiriman ditolak.
- **Pascakondisi:** Pesanan tersimpan dengan nomor unik dan terlihat di Pesanan Saya.
- **Aturan:** BR-01, BR-02.

#### UC-R02 Melihat Pesanan
- **Menu Figma:** Pesanan Saya
- **Alur utama:** Retail melihat daftar pesanannya (filter status dan tanggal), membuka detail (item, harga, status, riwayat status, info pengiriman). Status *Diproses* dan *Dikirim* yang diperbarui Admin tampil di sini, sehingga Retail dapat memantau pesanannya.
- **Alur alternatif:** Tidak ada pesanan → tampilan kosong dengan ajakan membuat pesanan. Pesanan berstatus *Dikirim* → tersedia tombol konfirmasi penerimaan (UC-R07).
- **Pascakondisi:** Tidak ada perubahan data (read-only).
- **Catatan:** Pembatalan pesanan oleh Retail belum ada pada diagram. **[TBC]**

#### UC-R03 Melihat Laporan Barang
- **Menu Figma:** Laporan Barang
- **Alur utama:** Retail melihat riwayat laporan barang miliknya beserta status laporan, keputusan klaim, dan status retur terkait.
- **Pascakondisi:** Read-only.

#### UC-R04 Melaporkan Barang
- **Menu Figma:** Laporan Barang
- **Prasyarat:** Terdapat pesanan berstatus *Diterima* (setelah UC-R07).
- **Alur utama:**
  1. Retail memilih pesanan dan item bermasalah.
  2. Retail memilih jenis masalah (mis. rusak, kemasan cacat, kedaluwarsa, salah kirim, jumlah tidak sesuai) **[ASUMSI: daftar jenis perlu dikonfirmasi]**.
  3. Retail mengisi kuantitas, deskripsi, dan mengunggah foto bukti.
  4. Retail mengirim laporan.
  5. Sistem menyimpan laporan, memberi nomor, dan menotifikasi Sales serta Warehouse.
- **Alur alternatif:** Foto bukti belum ada → laporan tidak dapat dikirim. Melebihi batas waktu pelaporan → ditolak **[TBC: batas waktu]**.
- **Pascakondisi:** Laporan berstatus *Dibuat*.
- **Aturan:** BR-04.

#### UC-R05 Retur Barang
- **Menu Figma:** Laporan Barang
- **Alur utama:**
  1. Retail memilih barang yang akan diretur (dari laporan atau dari pesanan) **[TBC]**.
  2. Retail mengisi alasan dan kuantitas retur.
  3. Retail mengirim pengajuan retur.
  4. Sistem membuat retur berstatus *Diajukan* dan menotifikasi Sales untuk dikonfirmasi.
- **Alur alternatif:** Kuantitas melebihi yang diterima → ditolak.
- **Pascakondisi:** Retur terlihat di riwayat dan menunggu konfirmasi Sales (UC-S03).

#### UC-R06 Melihat Profil Retail
- **Menu Figma:** (tidak ada di sidebar) **[TBC]**
- **Alur utama:** Retail melihat data tokonya (nama, alamat, kontak, sales pendamping, distributor).
- **Pascakondisi:** Read-only. **[TBC]** Apakah pengeditan profil diperlukan.

#### UC-R07 Konfirmasi Penerimaan Pesanan *(baru, berdasarkan jawaban klien)*
- **Menu Figma:** Pesanan Saya (belum berupa menu sendiri) **[TBC]**
- **Prasyarat:** Pesanan berstatus *Dikirim*.
- **Alur utama:**
  1. Retail membuka detail pesanan berstatus *Dikirim*.
  2. Retail memeriksa barang yang tiba, lalu memilih "Konfirmasi Diterima".
  3. Sistem mengubah status menjadi *Diterima*, mencatat pelaku dan waktu, dan menotifikasi Sales dan Admin.
- **Alur alternatif:** Barang tidak sesuai atau rusak → Retail tetap dapat mengonfirmasi lalu melapor lewat UC-R04 **[TBC: apakah penerimaan sebagian didukung]**. Retail tidak mengonfirmasi dalam batas waktu tertentu → **[TBC: apakah status otomatis berubah dan berapa lama]**.
- **Pascakondisi:** Pesanan berstatus *Diterima* dan terbuka untuk pelaporan barang (UC-R04).
- **Aturan:** BR-08, BR-10.

---

### 4.3 Aktor: Sales

#### UC-S01 Membuat Pesanan *(dipakai bersama Retail)*
- **Menu Figma:** Buat Pesanan Toko
- **Alur utama:**
  1. Sales memilih toko dari daftar toko binaan.
  2. Sales memilih produk dan kuantitas, memeriksa ringkasan.
  3. Sales mengirim pesanan atas nama toko.
  4. Sistem membuat pesanan dengan sumber = Sales.
- **Alur alternatif:** Toko bukan binaan Sales → tidak dapat dipilih.
- **Pascakondisi:** Pesanan tersimpan. **[TBC]** Status awal: langsung *Dikonfirmasi* atau menunggu konfirmasi toko.

#### UC-S02 Konfirmasi Pesanan
- **Menu Figma:** Konfirmasi Pesanan Toko
- **Prasyarat:** Ada pesanan berstatus *Menunggu Konfirmasi Sales* dari toko binaan.
- **Alur utama:**
  1. Sales membuka daftar pesanan yang menunggu konfirmasi.
  2. Sales memeriksa detail pesanan.
  3. Sales mengonfirmasi pesanan.
  4. Sistem mengubah status menjadi *Dikonfirmasi*, menotifikasi Retail, dan menampilkan pesanan kepada Admin untuk diproses.
- **Alur alternatif:** Sales menolak dengan alasan wajib → status *Ditolak*, Retail dinotifikasi.
- **Pascakondisi:** Pesanan terkonfirmasi tampil di UC-A01.
- **Aturan:** BR-01, BR-06.

#### UC-S03 Konfirmasi Retur
- **Menu Figma:** Penjemputan Retur **[TBC: apakah sama]**
- **Prasyarat:** Ada retur berstatus *Diajukan*.
- **Alur utama:**
  1. Sales melihat daftar pengajuan retur dari toko binaan.
  2. Sales memeriksa detail (barang, alasan, bukti).
  3. Sales menyetujui retur dan menetapkan penjemputan.
  4. Sales menandai barang telah dijemput **[ASUMSI: bukti berupa foto atau tanda tangan]**.
  5. Sistem memperbarui status dan menotifikasi Retail serta Warehouse.
- **Alur alternatif:** Sales menolak dengan alasan wajib → status *Ditolak*.
- **Pascakondisi:** Retur masuk pantauan logistik retur Warehouse (UC-W05).

#### UC-S04 Melihat Laporan Retail
- **Menu Figma:** Laporan Masuk dari Toko
- **Alur utama:** Sales melihat laporan barang dari toko binaan (filter toko, status, tanggal) dan membuka detail beserta foto bukti.
- **Pascakondisi:** Read-only.

#### UC-S05 Melihat Profil Toko
- **Menu Figma:** Profil Toko
- **Alur utama:** Sales melihat detail toko binaan: identitas, alamat, kontak, riwayat pesanan, dan riwayat laporan.
- **Pascakondisi:** Read-only. **[TBC]** Apakah Sales dapat menambah atau mengubah data toko.

#### UC-S06 Rute & Kunjungan *(baru, berdasarkan jawaban klien)*
- **Menu Figma:** Rute & Kunjungan
- **Latar belakang:** Setiap minggu Sales memiliki jadwal khusus kunjungan ke retail. Hari kunjungan tidak tetap, sehingga jadwal bersifat per minggu dan bukan jadwal berulang harian tetap.
- **Prasyarat:** Sales memiliki toko binaan.
- **Alur utama:**
  1. Sales membuka tampilan jadwal kunjungan minggu berjalan (daftar per hari, dan dapat berpindah minggu).
  2. Sales memilih kunjungan untuk melihat detail toko (alamat, kontak, riwayat pesanan, laporan terbuka) dan membuka UC-S05.
  3. Pada hari kunjungan, Sales mulai kunjungan, mencatat hasil kunjungan (catatan, tindak lanjut), dan menandai selesai **[ASUMSI: dengan check-in lokasi, TBC]**.
  4. Dari kunjungan, Sales dapat langsung membuat pesanan untuk toko tersebut (UC-S01).
  5. Sistem memperbarui status kunjungan.
- **Alur alternatif:** Toko dikunjungi di luar jadwal → dicatat sebagai kunjungan tambahan **[ASUMSI]**. Kunjungan tidak terlaksana → ditandai *Terlewat* atau dijadwalkan ulang dengan alasan **[ASUMSI]**.
- **Pascakondisi:** Riwayat kunjungan tersimpan dan dapat menjadi masukan untuk UC-S07.
- **Aturan:** BR-05, BR-09.
- **[TBC]** Siapa yang menyusun jadwal mingguan (Sales sendiri atau ditetapkan Admin/atasan). Apakah perlu peta dan urutan rute (optimasi), check-in berbasis lokasi, dan pengingat otomatis. Apakah perlu dukungan offline (NFR-04).

#### UC-S07 Kinerja dan Analisis Penjualan *(baru, berdasarkan jawaban klien)*
- **Menu Figma:** Kinerja dan Insentif
- **Tujuan:** Menyajikan data analisis penjualan berupa grafik, data, dan angka yang dibutuhkan untuk pengambilan keputusan bisnis.
- **Alur utama:**
  1. Sales membuka halaman kinerja dan memilih periode (minggu, bulan, rentang kustom).
  2. Sistem menampilkan ringkasan angka: total penjualan, jumlah pesanan, jumlah toko aktif memesan, nilai rata-rata pesanan **[ASUMSI]**.
  3. Sistem menampilkan grafik tren penjualan per periode, serta rincian per toko dan per produk **[ASUMSI]**.
  4. Sales dapat membandingkan dengan periode sebelumnya, dan melihat target vs realisasi bila target ditetapkan **[TBC]**.
  5. Sales dapat membuka detail (drill-down) ke daftar pesanan sumber.
- **Alur alternatif:** Tidak ada data pada periode terpilih → tampilan kosong.
- **Pascakondisi:** Read-only. Penjualan dihitung dari pesanan berstatus *Diterima* atau *Selesai* **[ASUMSI]**.
- **Aturan:** BR-05, BR-09.
- **[TBC]** Rumus dan aturan perhitungan **insentif** (dasar perhitungan, tarif, target). Apakah nilai insentif ditampilkan. Apakah pihak lain (Admin atau manajemen) perlu melihat kinerja seluruh Sales dan, bila ya, perlu aktor atau menu baru. Apakah ada ekspor data.

---

### 4.4 Aktor: Admin (Distributor)

#### UC-A01 Melihat dan Memproses Pesanan Retail
- **Menu Figma:** Pesanan Retail
- **Prasyarat:** Ada pesanan berstatus *Dikonfirmasi*.
- **Alur utama:**
  1. Admin melihat daftar pesanan yang telah dikonfirmasi Sales (filter status, toko, tanggal) dan membuka detail.
  2. Admin memeriksa ketersediaan stok untuk item pesanan.
  3. Admin memproses pesanan. Sistem mengubah status menjadi *Diproses*, mencatat pelaku dan waktu, dan menotifikasi Retail dan Sales.
  4. Pesanan *Diproses* siap dikirim dan dilanjutkan di UC-A02.
- **Alur alternatif:** Stok tidak mencukupi → pesanan tidak dapat diproses penuh **[TBC: ditunda, diproses sebagian, atau dibatalkan dengan alasan wajib sesuai BR-06]**.
- **Pascakondisi:** Pesanan berstatus *Diproses*.
- **Aturan:** BR-01, BR-02, BR-08.

#### UC-A02 Tracking Pengiriman
- **Menu Figma:** Pengiriman
- **Prasyarat:** Pesanan berstatus *Diproses*.
- **Alur utama:**
  1. Admin melihat daftar pesanan yang siap dan sedang dikirim beserta statusnya.
  2. Admin memperbarui status pesanan menjadi *Dikirim* saat barang diberangkatkan, dengan mengisi tanggal kirim, estimasi tiba, dan catatan **[ASUMSI: nomor surat jalan opsional]**.
  3. Sistem mencatat pelaku dan waktu, mengurangi stok sesuai item yang dikirim (UC-A03, BR-07), dan menotifikasi Retail dan Sales.
  4. Admin dapat memantau pesanan *Dikirim* yang belum dikonfirmasi diterima oleh Retail.
- **Alur alternatif:** Stok pada saat pengiriman tidak cukup → pembaruan status ditolak dan Admin diminta menyesuaikan stok atau pesanan.
- **Pascakondisi:** Pesanan berstatus *Dikirim*. Status *Diterima* hanya dapat diubah oleh Retail (UC-R07), bukan oleh Admin.
- **Aturan:** BR-07, BR-08, BR-10.
- **[TBC]** Apakah ada pengiriman parsial (satu pesanan, beberapa pengiriman).

#### UC-A03 Kelola Stok
- **Menu Figma:** Stok Gudang
- **Alur utama:**
  1. Admin melihat stok per produk.
  2. Admin menambah stok masuk atau menyesuaikan stok dengan alasan.
  3. Sistem mencatat mutasi stok (waktu, pelaku, jumlah, alasan).
- **Alur alternatif:** Penyesuaian membuat stok negatif → ditolak.
- **Fungsi pendukung:** Peringatan stok minimum, riwayat mutasi. Pengurangan stok otomatis saat pesanan berstatus *Dikirim*.
- **Aturan:** BR-02, BR-07.

#### UC-A04 Kelola Produk
- **Menu Figma:** Katalog Harga **[TBC: apakah sama]**
- **Alur utama:** Admin menambah, mengubah, menonaktifkan produk (nama, kode, kategori, satuan, harga, foto, status aktif).
- **Alur alternatif:** Produk yang sudah dipakai di pesanan tidak dihapus permanen, hanya dinonaktifkan.
- **Aturan:** BR-02. **[TBC]** Apakah ada harga khusus per toko atau per tier.

#### UC-A05 Melihat Daftar Retailer
- **Menu Figma:** Retailer
- **Alur utama:** Admin melihat daftar toko (pencarian dan filter wilayah), membuka ringkasan toko dan riwayat transaksinya.
- **Pascakondisi:** Read-only. **[TBC]** Siapa yang mendaftarkan atau menonaktifkan toko.

#### UC-A06 Melihat Ulasan
- **Menu Figma:** Ulasan/Review
- **Alur utama:** Admin melihat ulasan (rating dan komentar) dari Retail, filter berdasarkan rating, tanggal, dan toko.
- **Pascakondisi:** Read-only. **[TBC]** Apakah Admin dapat membalas ulasan.

---

### 4.5 Aktor: Warehouse

#### UC-W01 Melihat Sebaran Retail
- **Menu Figma:** Sebaran Retail
- **Alur utama:** Warehouse melihat persebaran toko per wilayah (peta dan/atau daftar) dengan indikator volume pesanan dan jumlah laporan; filter wilayah dan periode.
- **Pascakondisi:** Read-only. **[TBC]** Tersedianya koordinat toko.

#### UC-W02 Melihat Akar Permasalahan
- **Menu Figma:** Akar Permasalahan
- **Alur utama:** Warehouse melihat agregasi laporan berdasarkan kategori penyebab, produk, wilayah, dan periode; peringkat dan tren; drill-down ke daftar laporan sumber.
- **Pascakondisi:** Read-only. **[TBC]** Siapa yang menentukan kategori penyebab (Retail saat melapor atau Warehouse saat meninjau).

#### UC-W03 Kelola Otoritas Klaim
- **Menu Figma:** Otoritas Klaim
- **Prasyarat:** Ada laporan barang berstatus *Dibuat* atau *Ditinjau*.
- **Alur utama:**
  1. Warehouse membuka daftar klaim yang menunggu keputusan.
  2. Warehouse memeriksa laporan, foto bukti, dan riwayat pesanan.
  3. Warehouse memutuskan *Disetujui* atau *Ditolak* beserta alasan.
  4. Sistem menyimpan keputusan dan menotifikasi Retail dan Sales.
- **Alur alternatif:** Bukti kurang → Warehouse meminta bukti tambahan (status *Perlu Bukti Tambahan*).
- **Pascakondisi:** Keputusan tercatat permanen di audit trail. **[TBC]** Bentuk kompensasi klaim (ganti barang, kredit, lainnya).
- **Aturan:** BR-03, BR-06.

#### UC-W04 Melihat Mutu Kemasan
- **Menu Figma:** Mutu Kemasan
- **Alur utama:** Warehouse melihat rekap temuan kemasan bermasalah per produk dan batch, persentase kerusakan, dan skor mutu; filter periode.
- **Pascakondisi:** Read-only. **[TBC]** Rumus skor mutu dan apakah ada data batch.

#### UC-W05 Melihat Laporan Logistik Retur
- **Menu Figma:** Logistik Retur
- **Alur utama:** Warehouse memantau seluruh retur berdasarkan status (diajukan, dikonfirmasi, menunggu jemput, dijemput, diterima gudang, selesai), dan membuka detail.
- **Pascakondisi:** Read-only. **[TBC]** Apakah Warehouse juga mencatat penerimaan fisik barang retur dan tindak lanjutnya (restock, musnahkan, kembali ke pemasok).

#### UC-W06 Melihat Laporan Retail
- **Menu Figma:** Laporan
- **Alur utama:** Warehouse melihat laporan konsolidasi dari seluruh toko dengan filter wilayah, toko, status, dan periode; ekspor **[ASUMSI: PDF/Excel]**.
- **Pascakondisi:** Read-only.

---

### 4.6 Dashboard Beranda per Aktor (FR-COM-03)

Dashboard adalah halaman awal setelah login, berisi ringkasan angka dan pintasan ke tugas yang menunggu tindakan. Isi di bawah adalah usulan **[ASUMSI]**, metrik final perlu dikonfirmasi klien **[TBC]**.

| Aktor | Isi usulan |
|---|---|
| Retail | Pesanan aktif per status, pesanan *Dikirim* yang menunggu konfirmasi diterima, laporan barang dan retur yang sedang berjalan, pintasan Buat Pesanan |
| Sales | Pesanan menunggu konfirmasi, retur menunggu konfirmasi, kunjungan hari ini dan minggu ini, ringkasan penjualan periode berjalan |
| Admin | Pesanan *Dikonfirmasi* yang perlu diproses, pesanan *Diproses* yang siap dikirim, pesanan *Dikirim* belum diterima, peringatan stok minimum |
| Warehouse | Klaim menunggu keputusan, retur dalam proses, ringkasan akar permasalahan dan mutu kemasan periode berjalan |

---

## 5. Status dan Aturan Bisnis

### 5.1 Status
| Entitas | Status |
|---|---|
| **Pesanan** | Diajukan → Menunggu Konfirmasi Sales → Dikonfirmasi / Ditolak → Diproses (oleh Admin) → Dikirim (oleh Admin) → Diterima (oleh Retail) → Selesai / Dibatalkan **[TBC: kapan status *Selesai* dan siapa yang dapat membatalkan]** |
| **Laporan Barang dan Klaim** | Dibuat → Ditinjau → Perlu Bukti Tambahan → Disetujui / Ditolak |
| **Retur** | Diajukan → Dikonfirmasi Sales → Menunggu Penjemputan → Dijemput → Diterima Gudang → Selesai / Ditolak |
| **Kunjungan** | Dijadwalkan → Berlangsung → Selesai / Terlewat **[ASUMSI]** |

### 5.2 Aturan Bisnis
| ID | Aturan |
|---|---|
| BR-01 | Pesanan dari Retail wajib dikonfirmasi Sales sebelum tampil sebagai pesanan aktif bagi Admin. |
| BR-02 | Hanya Admin yang dapat mengubah produk dan stok. Retail dan Sales hanya melihat produk aktif. |
| BR-03 | Hanya Warehouse yang berwenang memutuskan klaim. Sales dan Admin tidak dapat mengubah keputusan klaim. |
| BR-04 | Laporan barang wajib memuat foto bukti dan terkait ke pesanan yang valid. |
| BR-05 | Sales hanya melihat toko, pesanan, laporan, jadwal kunjungan, dan data kinerja dari toko binaannya. Cakupan data Admin dan Warehouse mengikuti wilayah atau distribusinya **[TBC]**. |
| BR-06 | Penolakan (pesanan, retur, klaim) dan pembatalan wajib menyertakan alasan. |
| BR-07 | Stok berkurang saat Admin mengubah status pesanan menjadi *Dikirim* **[ASUMSI: bukan saat *Diproses*]**, dan bertambah bila barang retur dikembalikan ke stok **[TBC]**. |
| BR-08 | Setiap perubahan status tercatat (pelaku, waktu, alasan) dan tidak dapat dihapus. |
| BR-09 | Jadwal kunjungan dan data kinerja penjualan Sales bersifat pribadi bagi Sales yang bersangkutan, kecuali klien menetapkan pihak lain yang berhak melihat **[TBC]**. |
| BR-10 | Status *Diproses* dan *Dikirim* hanya dapat diubah oleh Admin. Status *Diterima* hanya dapat diubah oleh Retail pemilik pesanan dan hanya dari status *Dikirim*. |

---

## 6. Kebutuhan Non-Fungsional

| ID | Kategori | Kebutuhan |
|---|---|---|
| NFR-01 | Kinerja | Layar utama termuat < 3 detik pada jaringan 4G. Daftar memakai pagination. Halaman grafik kinerja memuat data teragregasi, bukan data mentah |
| NFR-02 | Keamanan | HTTPS, autentikasi token (JWT/OAuth2), RBAC di server, validasi input, penyimpanan token aman di perangkat |
| NFR-03 | Privasi | Data lokasi dan foto dikumpulkan dengan persetujuan. Akses data dibatasi per peran dan cakupan |
| NFR-04 | Konektivitas | Sales kerap di lapangan, sehingga disarankan dukungan offline parsial (jadwal kunjungan, draf pesanan, daftar toko) dengan sinkronisasi **[TBC]** |
| NFR-05 | Ketersediaan | Target uptime ≥ 99% **[ASUMSI]** |
| NFR-06 | Auditabilitas | Riwayat status dan keputusan klaim tidak dapat dihapus |
| NFR-07 | Skalabilitas | API terpisah dari klien, basis data relasional, object storage untuk foto bukti |
| NFR-08 | Lokalisasi | Bahasa Indonesia, mata uang Rupiah, zona waktu **[TBC]** |
| NFR-09 | Kegunaan | Mengikuti desain Figma klien. Ukuran sentuh nyaman untuk pengguna lapangan |
| NFR-10 | Unggahan | Foto dikompresi sebelum unggah, batas ukuran dan jumlah per laporan **[TBC]** |

---

## 7. Model Data Tingkat Tinggi

**Entitas:** User, Role, Retailer, SalesAssignment (relasi Sales–Retailer), Wilayah, Produk, KategoriProduk, HargaProduk, StokProduk, MutasiStok, Pesanan, ItemPesanan, Pengiriman, LaporanBarang, ItemLaporan, FotoBukti, Klaim, Retur, ItemRetur, Ulasan, JadwalKunjungan, CatatanKunjungan, TargetPenjualan **[TBC]**, Notifikasi, AuditLog.

**Atribut kunci**
- `Pesanan`: sumber (Retail/Sales), dibuat oleh, dikonfirmasi oleh, waktu konfirmasi, diproses oleh, waktu proses, waktu kirim, dikonfirmasi diterima oleh (Retail), waktu diterima, status, total.
- `Retur`: terkait ke `Pesanan` dan `LaporanBarang` (opsional), status, dikonfirmasi oleh, waktu jemput.
- `Klaim`: terkait ke `LaporanBarang`, keputusan, alasan, diputuskan oleh, waktu.
- `Pengiriman`: terkait ke `Pesanan`, status, tanggal kirim, estimasi tiba, catatan. Sumber pembaruan status = Admin.
- `JadwalKunjungan`: Sales, Retailer, tanggal kunjungan (berbeda tiap minggu), status, waktu mulai dan selesai, hasil dan catatan kunjungan, asal jadwal (disusun sendiri/ditetapkan) **[TBC]**.

**Relasi utama**
- Retailer–Sales: banyak ke banyak melalui `SalesAssignment` (menentukan visibilitas data Sales dan toko yang dapat dijadwalkan kunjungan).
- Pesanan–Pengiriman: satu ke banyak **[TBC: pengiriman parsial]**.
- LaporanBarang–Klaim: satu ke satu. LaporanBarang–Retur: satu ke banyak **[TBC]**.
- Sales–JadwalKunjungan: satu ke banyak. Retailer–JadwalKunjungan: satu ke banyak.
- Data kinerja Sales (UC-S07) diturunkan dari `Pesanan` (sumber dan toko binaan), `ItemPesanan`, `JadwalKunjungan`, tanpa tabel agregat wajib.

---

## 8. Arsitektur dan Rekomendasi Teknis

- **Klien:** satu aplikasi mobile dengan navigasi dinamis berdasarkan peran (bukan empat aplikasi terpisah, kecuali klien menghendaki).
- **Backend:** REST API dengan modul terpisah: Auth, Order, Delivery, Inventory/Product, Report/Claim, Return, Visit, Analytics (kinerja penjualan dan analitik Warehouse), Notification. Mulai sebagai monolit modular, dapat dipecah menjadi service bila skala menuntut.
- **Penyimpanan:** basis data relasional (MySQL/PostgreSQL), object storage untuk foto bukti, antrean untuk notifikasi dan pekerjaan latar.
- **Integrasi:** push notification (FCM), peta dan lokasi untuk sebaran retail dan kunjungan, ekspor laporan, pustaka grafik pada klien.
- **Lingkungan:** dev, staging, produksi dengan CI/CD dan backup basis data terjadwal.

---

## 9. Metrik Keberhasilan

- Waktu rata-rata dari pesanan dibuat sampai dikonfirmasi Sales.
- Waktu rata-rata dari *Dikonfirmasi* sampai *Diproses* dan *Dikirim* oleh Admin.
- Waktu rata-rata dari *Dikirim* sampai dikonfirmasi *Diterima* oleh Retail.
- Persentase pesanan terkirim tepat waktu.
- Tingkat laporan barang dan retur terhadap total pesanan.
- Waktu rata-rata penyelesaian klaim.
- Jumlah toko aktif memesan lewat aplikasi per bulan.
- Persentase kunjungan terjadwal yang terlaksana.
- Tingkat adopsi dan retensi pengguna per peran.

---

## 10. Risiko dan Mitigasi

| Risiko | Mitigasi |
|---|---|
| Requirement belum rinci, dan Figma belum selaras penuh dengan use case | Workshop konfirmasi per aktor. Rilis bertahap per modul. Perbarui Use Case Diagram dengan UC-R07, UC-S06, UC-S07 |
| Status pengiriman bergantung pada input manual Admin, sehingga bisa terlambat atau terlewat | Notifikasi pengingat untuk pesanan *Diproses* yang belum dikirim dan pesanan *Dikirim* yang belum diterima. Pertimbangkan batas waktu konfirmasi otomatis (pertanyaan 13) |
| Aturan insentif dan jadwal kunjungan belum rinci | Selesaikan pertanyaan 10 dan 11 (Bagian 12.2) sebelum desain Fase 4 |
| Konektivitas lemah di lapangan | Mode offline parsial dan sinkronisasi |
| Aturan klaim dan retur belum tertulis | Minta SOP tertulis dari klien |
| Data awal (toko, produk, harga) tidak bersih | Rencana migrasi dan impor data awal |

---

## 11. Usulan Fase Rilis

| Fase | Cakupan |
|---|---|
| **Fase 1: Fondasi** | Autentikasi, RBAC, manajemen akun, UC-A04 Kelola Produk, UC-A05 Daftar Retailer, UC-R06 dan UC-S05 profil |
| **Fase 2: Transaksi inti** | UC-R01, UC-R02, UC-R07, UC-S01, UC-S02, UC-A01, UC-A02, UC-A03, notifikasi, Dashboard dasar |
| **Fase 3: Laporan, klaim, retur** | UC-R03, UC-R04, UC-R05, UC-S03, UC-S04, UC-W03, UC-W05, UC-W06 |
| **Fase 4: Analitik dan kinerja Sales** | UC-W01, UC-W02, UC-W04, UC-A06, UC-S06 Rute & Kunjungan, UC-S07 Kinerja dan Analisis Penjualan, penyempurnaan Dashboard |

> Catatan: UC-S06 dapat dimajukan ke Fase 2 bila jadwal kunjungan dianggap kritis bagi operasional Sales.

---

## 12. Keputusan dan Pertanyaan

### 12.1 Keputusan yang Sudah Dikonfirmasi Klien

| No | Keputusan | Dampak pada dokumen |
|---|---|---|
| K1 | Admin yang memproses pesanan setelah dikonfirmasi Sales | UC-A01, status *Diproses*, BR-10 |
| K2 | Admin memperbarui status pengiriman menjadi *Dikirim* (tanpa aplikasi driver) | UC-A02, BR-07, out of scope aplikasi driver |
| K3 | Retail yang mengonfirmasi pesanan sampai dengan status *Diterima* | UC-R07 (baru), UC-R04 prasyarat, BR-10 |
| K4 | Rute & Kunjungan: Sales punya jadwal kunjungan ke retail setiap minggu, harinya tidak tentu | UC-S06 (baru), Alur E, entitas JadwalKunjungan |
| K5 | Kinerja & Insentif: data analisis penjualan (grafik, data, angka) untuk keputusan bisnis | UC-S07 (baru) |
| K6 | Dashboard Beranda: dashboard biasa per aktor | FR-COM-03, Bagian 4.6 |

### 12.2 Pertanyaan Terbuka

| No | Pertanyaan | Dampak |
|---|---|---|
| 1 | Pesanan buatan Sales: perlu konfirmasi Retail atau langsung sah? | Alur B |
| 2 | Hubungan Melaporkan Barang, Klaim, dan Retur: apakah retur selalu didahului klaim disetujui? | Alur C, model data |
| 3 | Siapa yang menulis ulasan dan kapan? Use case "Memberi Ulasan" belum ada | UC-A06, Alur D |
| 4 | Siapa yang mendaftarkan akun dan menugaskan Sales ke toko? Perlu aktor Super Admin atau panel web? | FR-COM-07, ruang lingkup |
| 5 | Nama final aktor: Admin atau Distributor, Warehouse atau Warehouse Administrator | Terminologi seluruh dokumen |
| 6 | Apakah ada pembayaran, tagihan, atau tempo? | Ruang lingkup |
| 7 | Platform (Android/iOS) dan kebutuhan mode offline untuk Sales | Teknologi, estimasi |
| 8 | Bentuk kompensasi klaim dan batas waktu pelaporan barang | BR-03, BR-04 |
| 9 | Perkiraan jumlah pengguna, toko, dan pesanan per hari | Sizing infrastruktur |
| 10 | Rute & Kunjungan: siapa yang menyusun jadwal mingguan (Sales atau atasan), perlu peta/urutan rute, check-in lokasi, dan pengingat? | UC-S06, model data |
| 11 | Kinerja & Insentif: rumus insentif, ada target penjualan atau tidak, apakah pihak lain perlu melihat kinerja seluruh Sales, dan perlu ekspor? | UC-S07, BR-09, kemungkinan aktor baru |
| 12 | Dashboard: metrik final tiap aktor (usulan di Bagian 4.6 perlu divalidasi) | FR-COM-03 |
| 13 | Penerimaan dan pembatalan: apakah ada batas waktu konfirmasi diterima (dan status otomatis), penerimaan sebagian, serta pembatalan pesanan oleh siapa dan sampai status apa? Penanganan stok tidak cukup saat diproses? | UC-A01, UC-R07, status pesanan |

---

## 13. Matriks Keterlacakan (Figma ↔ Use Case)

| Aktor | Menu Figma | Use Case | Status |
|---|---|---|---|
| Retail | Dashboard Beranda | FR-COM-03 | Terdefinisi (metrik TBC) |
| Retail | Buat Pesanan | UC-R01 | Selaras |
| Retail | Pesanan Saya | UC-R02, UC-R07 | Satu menu, dua use case (UC-R07 baru, belum ada di diagram) |
| Retail | Laporan Barang | UC-R03, UC-R04, UC-R05 | Satu menu, tiga use case |
| Retail | (tidak ada) | UC-R06 | Menu belum ada di Figma |
| Sales | Dashboard Beranda | FR-COM-03 | Terdefinisi (metrik TBC) |
| Sales | Rute & Kunjungan | UC-S06 | Use case baru, belum ada di diagram |
| Sales | Buat Pesanan Toko | UC-S01 | Selaras |
| Sales | Konfirmasi Pesanan Toko | UC-S02 | Selaras |
| Sales | Penjemputan Retur | UC-S03 | Kemungkinan sama |
| Sales | Laporan Masuk dari Toko | UC-S04 | Selaras |
| Sales | Kinerja dan Insentif | UC-S07 | Use case baru, belum ada di diagram (rumus insentif TBC) |
| Sales | Profil Toko | UC-S05 | Selaras |
| Admin | Dashboard Beranda | FR-COM-03 | Terdefinisi (metrik TBC) |
| Admin | Pesanan Retail | UC-A01 | Selaras (diperluas: memproses pesanan) |
| Admin | Pengiriman | UC-A02 | Selaras (diperluas: memperbarui status *Dikirim*) |
| Admin | Stok Gudang | UC-A03 | Selaras |
| Admin | Retailer | UC-A05 | Selaras |
| Admin | Katalog Harga | UC-A04 | Kemungkinan sama |
| Admin | Ulasan/Review | UC-A06 | Selaras |
| Warehouse | Dashboard Beranda | FR-COM-03 | Terdefinisi (metrik TBC) |
| Warehouse | Sebaran Retail | UC-W01 | Selaras |
| Warehouse | Akar Permasalahan | UC-W02 | Selaras |
| Warehouse | Otoritas Klaim | UC-W03 | Selaras |
| Warehouse | Mutu Kemasan | UC-W04 | Selaras |
| Warehouse | Logistik Retur | UC-W05 | Selaras |
| Warehouse | Laporan | UC-W06 | Selaras |