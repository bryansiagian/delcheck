<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * Peran dan izin (RBAC) berdasarkan PRD v1.1, Bagian 2.1 (Matriks Hak Akses).
 *
 * Izin dengan akhiran "-sendiri" / "-binaan" / "-semua" hanya menyatakan CAKUPAN
 * yang boleh dilihat. Pembatasan datanya (mis. Sales hanya toko binaan, BR-05)
 * tetap harus diterapkan di Policy atau query scope.
 */
class RolePermissionSeeder extends Seeder
{
    private const GUARD = 'web';

    /** Peran => daftar izin */
    private function peta(): array
    {
        return [
            // ---------------------------------------------------------------
            'retail' => [
                'dashboard.lihat',
                'produk.lihat',                  // BR-02: hanya produk aktif
                'pesanan.buat',                  // UC-R01
                'pesanan.lihat-sendiri',         // UC-R02
                'pengiriman.pantau',             // UC-R02 (status Diproses/Dikirim)
                'pesanan.terima',                // UC-R07 (BR-10: hanya Retail)
                'laporan-barang.lihat-sendiri',  // UC-R03
                'laporan-barang.buat',           // UC-R04
                'retur.ajukan',                  // UC-R05
                'profil-toko.lihat-sendiri',     // UC-R06
            ],

            // ---------------------------------------------------------------
            'sales' => [
                'dashboard.lihat',
                'produk.lihat',
                'pesanan.buat',                  // UC-S01 (atas nama toko binaan)
                'pesanan.lihat-binaan',
                'pesanan.konfirmasi',            // UC-S02 (konfirmasi/tolak)
                'pengiriman.pantau',
                'retur.konfirmasi',              // UC-S03
                'laporan-barang.lihat-binaan',   // UC-S04
                'profil-toko.lihat-binaan',      // UC-S05
                'kunjungan.kelola',              // UC-S06 (BR-09: milik sendiri)
                'kinerja.lihat',                 // UC-S07 (BR-09: milik sendiri)
            ],

            // ---------------------------------------------------------------
            'admin' => [
                'dashboard.lihat',
                'produk.lihat',
                'produk.kelola',                 // UC-A04 (BR-02)
                'stok.kelola',                   // UC-A03 (BR-02)
                'pesanan.lihat-semua',           // UC-A01
                'pesanan.proses',                // UC-A01 (BR-10)
                'pengiriman.pantau',
                'pengiriman.perbarui',           // UC-A02 (Dikirim, BR-10)
                'retailer.lihat-daftar',         // UC-A05
                'ulasan.lihat',                  // UC-A06
            ],

            // ---------------------------------------------------------------
            'warehouse' => [
                'dashboard.lihat',
                'analitik.sebaran-retail',       // UC-W01
                'analitik.akar-masalah',         // UC-W02
                'klaim.putuskan',                // UC-W03 (BR-03: hanya Warehouse)
                'analitik.mutu-kemasan',         // UC-W04
                'retur.pantau-logistik',         // UC-W05
                'laporan-barang.lihat-semua',    // UC-W06
                'laporan-barang.ekspor',         // UC-W06 [ASUMSI: PDF/Excel]
            ],
        ];
    }

    public function run(): void
    {
        // Wajib: kosongkan cache izin Spatie sebelum seeding
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $peta = $this->peta();

        // 1. Buat semua izin (idempoten)
        $semuaIzin = collect($peta)->flatten()->unique()->values();

        foreach ($semuaIzin as $nama) {
            Permission::findOrCreate($nama, self::GUARD);
        }

        // 2. Buat peran dan sinkronkan izinnya (idempoten)
        foreach ($peta as $namaPeran => $izin) {
            Role::findOrCreate($namaPeran, self::GUARD)->syncPermissions($izin);
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
}
