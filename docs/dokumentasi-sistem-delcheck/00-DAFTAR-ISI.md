# Dokumentasi Sistem Delcheck

Dokumentasi reverse engineering berbasis source code repo. Label bukti: **[TERBUKTI DI KODE]**, **[KESIMPULAN ANALISIS]**, **[BELUM DAPAT DIPASTIKAN]**, dan **[PERLU PENGUJIAN]**. Root repo adalah `D:/KERJA/delcheck`.

## Daftar dokumen

1. [Gambaran umum](01-GAMBARAN-UMUM-SISTEM.md)
2. [Arsitektur dan struktur proyek](02-ARSITEKTUR-DAN-STRUKTUR-PROYEK.md)
3. [Role dan hak akses](03-ROLE-DAN-HAK-AKSES.md)
4. [Alur bisnis seluruh fitur](04-ALUR-BISNIS-SELURUH-FITUR.md)
5. [Frontend Flutter](05-DOKUMENTASI-FRONTEND-FLUTTER.md)
6. [Backend Laravel](06-DOKUMENTASI-BACKEND-LARAVEL.md)
7. [Kontrak API](07-DOKUMENTASI-API.md)
8. [Database](08-DOKUMENTASI-DATABASE.md)
9. [Migration dan ERD](09-DOKUMENTASI-MIGRATION-DAN-ERD.md)
10. [Alur data end-to-end](10-ALUR-DATA-END-TO-END.md)
11. [Autentikasi dan otorisasi](11-AUTENTIKASI-DAN-OTORISASI.md)
12. [Kamus istilah](12-KAMUS-ISTILAH-TEKNIS.md)
13. [Bug dan risiko](13-ANALISIS-BUG-DAN-RISIKO.md)
14. [Fitur dan mapping kode](14-DAFTAR-FITUR-DAN-MAPPING-KODE.md)
15. [Referensi file dan fungsi](15-REFERENSI-FILE-DAN-FUNGSI.md)

## Batas pemeriksaan

Dokumen membaca source, konfigurasi nonrahasia, route, migration, model, test, dan manifest paket. Tidak ada perintah migrasi, seeder, request API ke server, atau koneksi baca database aktual yang dijalankan. Karena itu schema di sini adalah **schema yang didefinisikan migration**, bukan bukti schema atau isi database aktif. PRD (`PRD.MD`) adalah kebutuhan draft, bukan bukti fitur telah tersedia. Tidak ada source code atau database yang diubah; hanya berkas Markdown dalam folder ini yang dibuat.
