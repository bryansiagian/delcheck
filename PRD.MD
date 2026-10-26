# PRD: Aplikasi Mobile Pendistribusian Barang

| Atribut | Nilai |
|---|---|
| Versi | 1.0 (Draft) |
| Status | Menunggu konfirmasi klien atas item bertanda **[TBC]** |
| Sumber requirement | Desain Figma klien (sidebar per aktor) dan Use Case Diagram "Pendistribusian Barang" |
| Platform target | Aplikasi mobile **[TBC: Android saja atau Android dan iOS]** |
| Bahasa antarmuka | Bahasa Indonesia |

**Konvensi dokumen**
- **[TBC]** = To Be Confirmed, butuh konfirmasi klien.
- **[ASUMSI]** = asumsi analis yang perlu divalidasi.
- ID: `UC-` use case, `FR-` kebutuhan fungsional, `BR-` aturan bisnis, `NFR-` non-fungsional.

---

## 1. Ringkasan Produk

### 1.1 Latar Belakang
Proses distribusi barang antara toko (retail), sales lapangan, distributor, dan pengawas gudang membutuhkan satu platform terpadu untuk pemesanan, pemantauan pengiriman dan stok, pelaporan barang bermasalah, klaim, serta retur. Aplikasi mobile ini menyatukan seluruh alur tersebut untuk empat aktor dengan peran berbeda.

### 1.2 Tujuan Produk
1. Mendigitalkan pemesanan barang, baik oleh Retail maupun oleh Sales atas nama toko.
2. Memberi Admin (distributor) visibilitas pesanan, pengiriman, dan stok.
3. Menyediakan alur pelaporan barang bermasalah, klaim, dan retur yang terlacak.
4. Memberi Warehouse alat analisis (sebaran retail, akar permasalahan, mutu kemasan, logistik retur) dan wewenang memutuskan klaim.

### 1.3 Ruang Lingkup
**In scope**
- Autentikasi dan hak akses berbasis peran.
- Seluruh use case pada Use Case Diagram (23 use case, Bagian 4).
- Dashboard Beranda per aktor, notifikasi, dan pelaporan.

**Perlu keputusan klien (ada di Figma, belum ada use case)**
- Sales: *Rute & Kunjungan*, *Kinerja dan Insentif*. **[TBC]**
- Dashboard Beranda semua aktor: isi dan metrik. **[TBC]**

**Out of scope (sementara) [ASUMSI]**
- Pembayaran online, tagihan, dan kredit/tempo.
- Integrasi ERP atau akuntansi.
- Aplikasi driver terpisah.
- Panel web super admin.

---

## 2. Aktor

| Aktor (Diagram) | Nama di Figma | Peran |
|---|---|---|
| **Retail** | Toko / Retail | Toko pemesan barang. Membuat pesanan, melaporkan barang bermasalah, mengajukan retur |
| **Sales** | Sales | Perwakilan penjualan. Membuat pesanan untuk toko, mengonfirmasi pesanan dan retur, memantau laporan dan profil toko binaan |
| **Admin** | Distributor | Pengelola operasional. Memantau pesanan dan pengiriman, mengelola stok dan produk, melihat retailer dan ulasan |
| **Warehouse** | Warehouse Administrator | Pengawas mutu dan klaim. Menganalisis data distribusi dan memutuskan klaim |

> **[TBC]** Nama final aktor: "Admin" atau "Distributor", "Warehouse" atau "Warehouse Administrator". Dokumen ini memakai nama pada use case diagram.

### 2.1 Matriks Hak Akses Ringkas

| Fungsi | Retail | Sales | Admin | Warehouse |
|---|:-:|:-:|:-:|:-:|
| Membuat pesanan | ✔ | ✔ | | |
| Mengonfirmasi pesanan | | ✔ | | |
| Melihat pesanan | ✔ (milik sendiri) | ✔ (toko binaan) | ✔ (semua) | |
| Tracking pengiriman | ✔ (milik sendiri) **[TBC]** | | ✔ | |
| Kelola produk dan stok | | | ✔ | |
| Melaporkan barang | ✔ | | | |
| Mengajukan retur | ✔ | | | |
| Konfirmasi retur | | ✔ | | |
| Melihat laporan retail | | ✔ (toko binaan) | | ✔ (semua) |
| Memutuskan klaim | | | | ✔ |
| Analitik (sebaran, akar masalah, mutu, logistik retur) | | | | ✔ |
| Melihat daftar retailer | | | ✔ | |
| Melihat ulasan | | | ✔ | |
| Melihat profil toko | ✔ (sendiri) | ✔ (toko binaan) | | |

---

## 3. Alur Bisnis

### Alur A: Pesanan dari Retail
1. Retail membuat pesanan (UC-R01).
2. Pesanan masuk ke Sales terkait dan menunggu konfirmasi.
3. Sales mengonfirmasi atau menolak (UC-S02).
4. Pesanan terkonfirmasi tampil bagi Admin (UC-A01).
5. Pengiriman dipantau (UC-A02) dan stok diperbarui (UC-A03).
6. Retail memantau status pesanan (UC-R02).

### Alur B: Pesanan dibuat Sales
1. Sales memilih toko binaan dan membuat pesanan (UC-S01).
2. **[TBC]** Apakah perlu konfirmasi dari Retail atau langsung terkonfirmasi.
3. Lanjut seperti Alur A langkah 4 sampai 6.

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

---

## 4. Spesifikasi Use Case

### 4.1 Fungsi Umum (di luar diagram, wajib ada)

| ID | Kebutuhan |
|---|---|
| FR-COM-01 | Login, logout, ubah kata sandi, dan reset kata sandi |
| FR-COM-02 | Kontrol akses berbasis peran (RBAC): tiap aktor hanya melihat menu dan data miliknya, diterapkan di sisi server |
| FR-COM-03 | Dashboard Beranda per aktor (metrik **[TBC]**) |
| FR-COM-04 | Notifikasi push dan in-app untuk perubahan status pesanan, pengiriman, laporan, klaim, dan retur |
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
- **Alur utama:** Retail melihat daftar pesanannya (filter status dan tanggal), membuka detail (item, harga, status, riwayat status, info pengiriman bila ada).
- **Alur alternatif:** Tidak ada pesanan → tampilan kosong dengan ajakan membuat pesanan.
- **Pascakondisi:** Tidak ada perubahan data (read-only).
- **Catatan:** Konfirmasi penerimaan barang dan pembatalan pesanan belum ada pada diagram. **[TBC]**

#### UC-R03 Melihat Laporan Barang
- **Menu Figma:** Laporan Barang
- **Alur utama:** Retail melihat riwayat laporan barang miliknya beserta status laporan, keputusan klaim, dan status retur terkait.
- **Pascakondisi:** Read-only.

#### UC-R04 Melaporkan Barang
- **Menu Figma:** Laporan Barang
- **Prasyarat:** Terdapat pesanan berstatus diterima.
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
  4. Sistem mengubah status menjadi *Dikonfirmasi*, menotifikasi Retail, dan menampilkan pesanan kepada Admin.
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

---

### 4.4 Aktor: Admin (Distributor)

#### UC-A01 Melihat Pesanan Retail
- **Menu Figma:** Pesanan Retail
- **Alur utama:** Admin melihat pesanan yang telah dikonfirmasi (filter status, toko, tanggal) dan membuka detail.
- **Pascakondisi:** Read-only. **[TBC]** Siapa yang memproses atau menyiapkan pesanan serta mengubah statusnya setelah dikonfirmasi.

#### UC-A02 Tracking Pengiriman
- **Menu Figma:** Pengiriman
- **Alur utama:** Admin melihat daftar pengiriman beserta status dan estimasi, serta membuka detail per pesanan.
- **Pascakondisi:** Read-only. **[TBC]** Sumber data status pengiriman (driver, input manual, atau sistem lain) dan apakah perlu pelacakan GPS.

#### UC-A03 Kelola Stok
- **Menu Figma:** Stok Gudang
- **Alur utama:**
  1. Admin melihat stok per produk.
  2. Admin menambah stok masuk atau menyesuaikan stok dengan alasan.
  3. Sistem mencatat mutasi stok (waktu, pelaku, jumlah, alasan).
- **Alur alternatif:** Penyesuaian membuat stok negatif → ditolak.
- **Fungsi pendukung:** Peringatan stok minimum, riwayat mutasi.
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

## 5. Status dan Aturan Bisnis

### 5.1 Status
| Entitas | Status |
|---|---|
| **Pesanan** | Diajukan → Menunggu Konfirmasi Sales → Dikonfirmasi / Ditolak → Diproses **[TBC]** → Dalam Pengiriman → Diterima → Selesai / Dibatalkan |
| **Laporan Barang dan Klaim** | Dibuat → Ditinjau → Perlu Bukti Tambahan → Disetujui / Ditolak |
| **Retur** | Diajukan → Dikonfirmasi Sales → Menunggu Penjemputan → Dijemput → Diterima Gudang → Selesai / Ditolak |

### 5.2 Aturan Bisnis
| ID | Aturan |
|---|---|
| BR-01 | Pesanan dari Retail wajib dikonfirmasi Sales sebelum tampil sebagai pesanan aktif bagi Admin. |
| BR-02 | Hanya Admin yang dapat mengubah produk dan stok. Retail dan Sales hanya melihat produk aktif. |
| BR-03 | Hanya Warehouse yang berwenang memutuskan klaim. Sales dan Admin tidak dapat mengubah keputusan klaim. |
| BR-04 | Laporan barang wajib memuat foto bukti dan terkait ke pesanan yang valid. |
| BR-05 | Sales hanya melihat toko, pesanan, dan laporan dari toko binaannya. Cakupan data Admin dan Warehouse mengikuti wilayah atau distribusinya **[TBC]**. |
| BR-06 | Penolakan (pesanan, retur, klaim) wajib menyertakan alasan. |
| BR-07 | Stok berkurang saat pengiriman dan bertambah bila barang retur dikembalikan ke stok **[TBC]**. |
| BR-08 | Setiap perubahan status tercatat (pelaku, waktu, alasan) dan tidak dapat dihapus. |

---

## 6. Kebutuhan Non-Fungsional

| ID | Kategori | Kebutuhan |
|---|---|---|
| NFR-01 | Kinerja | Layar utama termuat < 3 detik pada jaringan 4G. Daftar memakai pagination |
| NFR-02 | Keamanan | HTTPS, autentikasi token (JWT/OAuth2), RBAC di server, validasi input, penyimpanan token aman di perangkat |
| NFR-03 | Privasi | Data lokasi dan foto dikumpulkan dengan persetujuan. Akses data dibatasi per peran dan cakupan |
| NFR-04 | Konektivitas | Sales kerap di lapangan, sehingga disarankan dukungan offline parsial (draf pesanan, daftar toko) dengan sinkronisasi **[TBC]** |
| NFR-05 | Ketersediaan | Target uptime ≥ 99% **[ASUMSI]** |
| NFR-06 | Auditabilitas | Riwayat status dan keputusan klaim tidak dapat dihapus |
| NFR-07 | Skalabilitas | API terpisah dari klien, basis data relasional, object storage untuk foto bukti |
| NFR-08 | Lokalisasi | Bahasa Indonesia, mata uang Rupiah, zona waktu **[TBC]** |
| NFR-09 | Kegunaan | Mengikuti desain Figma klien. Ukuran sentuh nyaman untuk pengguna lapangan |
| NFR-10 | Unggahan | Foto dikompresi sebelum unggah, batas ukuran dan jumlah per laporan **[TBC]** |

---

## 7. Model Data Tingkat Tinggi

**Entitas:** User, Role, Retailer, SalesAssignment (relasi Sales–Retailer), Wilayah, Produk, KategoriProduk, HargaProduk, StokProduk, MutasiStok, Pesanan, ItemPesanan, Pengiriman, LaporanBarang, ItemLaporan, FotoBukti, Klaim, Retur, ItemRetur, Ulasan, Notifikasi, AuditLog.

**Atribut kunci**
- `Pesanan`: sumber (Retail/Sales), dibuat oleh, dikonfirmasi oleh, waktu konfirmasi, status, total.
- `Retur`: terkait ke `Pesanan` dan `LaporanBarang` (opsional), status, dikonfirmasi oleh, waktu jemput.
- `Klaim`: terkait ke `LaporanBarang`, keputusan, alasan, diputuskan oleh, waktu.
- `Pengiriman`: terkait ke `Pesanan`, status, sumber pembaruan status **[TBC]**.

**Relasi utama**
- Retailer–Sales: banyak ke banyak melalui `SalesAssignment` (menentukan visibilitas data Sales).
- Pesanan–Pengiriman: satu ke banyak.
- LaporanBarang–Klaim: satu ke satu. LaporanBarang–Retur: satu ke banyak **[TBC]**.

---

## 8. Arsitektur dan Rekomendasi Teknis

- **Klien:** satu aplikasi mobile dengan navigasi dinamis berdasarkan peran (bukan empat aplikasi terpisah, kecuali klien menghendaki).
- **Backend:** REST API dengan modul terpisah: Auth, Order, Delivery, Inventory/Product, Report/Claim, Return, Analytics, Notification. Mulai sebagai monolit modular, dapat dipecah menjadi service bila skala menuntut.
- **Penyimpanan:** basis data relasional (MySQL/PostgreSQL), object storage untuk foto bukti, antrean untuk notifikasi dan pekerjaan latar.
- **Integrasi:** push notification (FCM), peta dan lokasi untuk sebaran retail, ekspor laporan.
- **Lingkungan:** dev, staging, produksi dengan CI/CD dan backup basis data terjadwal.

---

## 9. Metrik Keberhasilan

- Waktu rata-rata dari pesanan dibuat sampai dikonfirmasi Sales.
- Persentase pesanan terkirim tepat waktu.
- Tingkat laporan barang dan retur terhadap total pesanan.
- Waktu rata-rata penyelesaian klaim.
- Jumlah toko aktif memesan lewat aplikasi per bulan.
- Tingkat adopsi dan retensi pengguna per peran.

---

## 10. Risiko dan Mitigasi

| Risiko | Mitigasi |
|---|---|
| Requirement belum rinci, dan Figma belum selaras penuh dengan use case | Workshop konfirmasi per aktor. Rilis bertahap per modul |
| Admin hanya melihat pesanan dan pengiriman, sehingga sumber data pemrosesan dan status belum jelas | Selesaikan pertanyaan 1 dan 2 (Bagian 12) sebelum desain basis data final |
| Konektivitas lemah di lapangan | Mode offline parsial dan sinkronisasi |
| Aturan klaim dan retur belum tertulis | Minta SOP tertulis dari klien |
| Data awal (toko, produk, harga) tidak bersih | Rencana migrasi dan impor data awal |

---

## 11. Usulan Fase Rilis

| Fase | Cakupan |
|---|---|
| **Fase 1: Fondasi** | Autentikasi, RBAC, manajemen akun, UC-A04 Kelola Produk, UC-A05 Daftar Retailer, UC-R06 dan UC-S05 profil |
| **Fase 2: Transaksi inti** | UC-R01, UC-R02, UC-S01, UC-S02, UC-A01, UC-A02, UC-A03, notifikasi, Dashboard dasar |
| **Fase 3: Laporan, klaim, retur** | UC-R03, UC-R04, UC-R05, UC-S03, UC-S04, UC-W03, UC-W05, UC-W06 |
| **Fase 4: Analitik dan penguatan** | UC-W01, UC-W02, UC-W04, UC-A06, serta Rute & Kunjungan dan Kinerja dan Insentif bila masuk ruang lingkup |

---

## 12. Daftar Pertanyaan Terbuka

| No | Pertanyaan | Dampak |
|---|---|---|
| 1 | Siapa yang memproses pesanan setelah dikonfirmasi Sales? Admin hanya "melihat" pesanan | Alur pesanan, status, hak akses |
| 2 | Siapa yang membuat dan memperbarui status pengiriman? Admin hanya "tracking" | Modul pengiriman, kebutuhan aplikasi driver |
| 3 | Pesanan buatan Sales: perlu konfirmasi Retail atau langsung sah? | Alur B |
| 4 | Hubungan Melaporkan Barang, Klaim, dan Retur: apakah retur selalu didahului klaim disetujui? | Alur C, model data |
| 5 | Apakah Rute & Kunjungan, Kinerja dan Insentif, dan Dashboard masuk ruang lingkup? Mohon dilengkapi use case-nya | Ruang lingkup, fase |
| 6 | Siapa yang menulis ulasan dan kapan? Use case "Memberi Ulasan" belum ada | UC-A06, Alur D |
| 7 | Siapa yang mendaftarkan akun dan menugaskan Sales ke toko? Perlu aktor Super Admin atau panel web? | FR-COM-07, ruang lingkup |
| 8 | Nama final aktor: Admin atau Distributor, Warehouse atau Warehouse Administrator | Terminologi seluruh dokumen |
| 9 | Apakah ada pembayaran, tagihan, atau tempo? | Ruang lingkup |
| 10 | Platform (Android/iOS) dan kebutuhan mode offline untuk Sales | Teknologi, estimasi |
| 11 | Bentuk kompensasi klaim dan batas waktu pelaporan barang | Aturan bisnis BR-03, BR-04 |
| 12 | Perkiraan jumlah pengguna, toko, dan pesanan per hari | Sizing infrastruktur |

---

## 13. Matriks Keterlacakan (Figma ↔ Use Case)

| Aktor | Menu Figma | Use Case | Status |
|---|---|---|---|
| Retail | Dashboard Beranda | FR-COM-03 | Perlu detail |
| Retail | Buat Pesanan | UC-R01 | Selaras |
| Retail | Pesanan Saya | UC-R02 | Selaras |
| Retail | Laporan Barang | UC-R03, UC-R04, UC-R05 | Satu menu, tiga use case |
| Retail | (tidak ada) | UC-R06 | Menu belum ada di Figma |
| Sales | Dashboard Beranda | FR-COM-03 | Perlu detail |
| Sales | Rute & Kunjungan | (tidak ada) | Belum ada use case |
| Sales | Buat Pesanan Toko | UC-S01 | Selaras |
| Sales | Konfirmasi Pesanan Toko | UC-S02 | Selaras |
| Sales | Penjemputan Retur | UC-S03 | Kemungkinan sama |
| Sales | Laporan Masuk dari Toko | UC-S04 | Selaras |
| Sales | Kinerja dan Insentif | (tidak ada) | Belum ada use case |
| Sales | Profil Toko | UC-S05 | Selaras |
| Admin | Dashboard Beranda | FR-COM-03 | Perlu detail |
| Admin | Pesanan Retail | UC-A01 | Selaras |
| Admin | Pengiriman | UC-A02 | Selaras |
| Admin | Stok Gudang | UC-A03 | Selaras |
| Admin | Retailer | UC-A05 | Selaras |
| Admin | Katalog Harga | UC-A04 | Kemungkinan sama |
| Admin | Ulasan/Review | UC-A06 | Selaras |
| Warehouse | Dashboard Beranda | FR-COM-03 | Perlu detail |
| Warehouse | Sebaran Retail | UC-W01 | Selaras |
| Warehouse | Akar Permasalahan | UC-W02 | Selaras |
| Warehouse | Otoritas Klaim | UC-W03 | Selaras |
| Warehouse | Mutu Kemasan | UC-W04 | Selaras |
| Warehouse | Logistik Retur | UC-W05 | Selaras |
| Warehouse | Laporan | UC-W06 | Selaras |