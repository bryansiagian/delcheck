<?php

namespace Database\Seeders;

use App\Enums\Peran;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Akun contoh untuk pengembangan. Hanya berjalan di environment local/testing.
 * Retail tidak dibuat di sini karena mendaftar sendiri lewat /api/auth/register.
 * Kata sandi semua akun: "password" (JANGAN dipakai di produksi).
 */
class UserSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            return;
        }

        $akun = [
            ['name' => 'Admin Distributor', 'email' => 'admin@example.test', 'phone' => '081200000001', 'peran' => Peran::Admin],
            ['name' => 'Sales Contoh', 'email' => 'sales@example.test', 'phone' => '081200000002', 'peran' => Peran::Sales],
            ['name' => 'Warehouse Contoh', 'email' => 'warehouse@example.test', 'phone' => '081200000003', 'peran' => Peran::Warehouse],
        ];

        foreach ($akun as $data) {
            $user = User::updateOrCreate(
                ['email' => $data['email']],
                [
                    'name' => $data['name'],
                    'phone' => $data['phone'],
                    'password' => 'password',
                    'is_active' => true,
                ],
            );

            $user->syncRoles($data['peran']->value);
        }
    }
}
