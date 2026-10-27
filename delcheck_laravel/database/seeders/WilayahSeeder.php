<?php

namespace Database\Seeders;

use App\Models\Wilayah;
use Illuminate\Database\Seeder;

/**
 * Data CONTOH untuk pengembangan. Ganti dengan data wilayah resmi sebelum produksi.
 * Urutan penting: induk harus muncul sebelum anaknya.
 */
class WilayahSeeder extends Seeder
{
    public function run(): void
    {
        $data = [
            // [kode, nama, tingkat, kode induk]
            ['12', 'Sumatera Utara', 'provinsi', null],
            ['1271', 'Kota Medan', 'kota', '12'],
            ['1207', 'Kabupaten Deli Serdang', 'kota', '12'],
            ['1275', 'Kota Binjai', 'kota', '12'],
            ['1212', 'Kabupaten Toba', 'kota', '12'],

            ['31', 'DKI Jakarta', 'provinsi', null],
            ['3173', 'Kota Jakarta Pusat', 'kota', '31'],
        ];

        foreach ($data as [$kode, $nama, $tingkat, $kodeInduk]) {
            Wilayah::updateOrCreate(
                ['kode' => $kode],
                [
                    'nama' => $nama,
                    'tingkat' => $tingkat,
                    'parent_id' => $kodeInduk ? Wilayah::where('kode', $kodeInduk)->value('id') : null,
                ],
            );
        }
    }
}
