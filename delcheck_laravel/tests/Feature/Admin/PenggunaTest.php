<?php

namespace Tests\Feature\Admin;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Models\Retailer;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PenggunaTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    private function buatUser(Peran $peran, array $atribut = []): User
    {
        $user = User::factory()->create(array_merge(['is_active' => true], $atribut));
        $user->assignRole($peran->value);

        return $user;
    }

    public function test_daftar_pengguna_butuh_login(): void
    {
        $this->getJson('/api/admin/pengguna')->assertUnauthorized();
    }

    public function test_non_admin_tidak_boleh_mengakses(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $this->getJson('/api/admin/pengguna')->assertForbidden();
    }

    public function test_admin_melihat_daftar_dan_filter_role(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $this->buatUser(Peran::Sales, ['name' => 'Sales Satu']);
        $this->buatUser(Peran::Warehouse);
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/pengguna')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['items' => [['id', 'name', 'is_active', 'roles']], 'meta']]);

        $nama = collect($this->getJson('/api/admin/pengguna?role=sales')->assertOk()->json('data.items'))->pluck('name');
        $this->assertSame(['Sales Satu'], $nama->all());
    }

    public function test_admin_menonaktifkan_akun_dan_token_dicabut(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $sales = $this->buatUser(Peran::Sales);
        $sales->createToken('mobile');
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pengguna/{$sales->id}/nonaktifkan")
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->assertFalse($sales->fresh()->is_active);
        $this->assertSame(0, $sales->fresh()->tokens()->count());
    }

    public function test_admin_tidak_bisa_menonaktifkan_diri_sendiri(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pengguna/{$admin->id}/nonaktifkan")->assertForbidden();

        $this->assertTrue($admin->fresh()->is_active);
    }

    public function test_menonaktifkan_akun_yang_sudah_nonaktif_ditolak(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $sales = $this->buatUser(Peran::Sales, ['is_active' => false]);
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pengguna/{$sales->id}/nonaktifkan")->assertStatus(409);
    }

    public function test_admin_mengaktifkan_akun(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $sales = $this->buatUser(Peran::Sales, ['is_active' => false]);
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pengguna/{$sales->id}/aktifkan")
            ->assertOk()
            ->assertJsonPath('data.is_active', true);

        $this->assertTrue($sales->fresh()->is_active);
    }

    public function test_akun_retail_belum_disetujui_tidak_bisa_diaktifkan_dari_sini(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $akunToko = $this->buatUser(Peran::Retail, ['is_active' => false]);
        Retailer::create([
            'user_id' => $akunToko->id,
            'kode' => 'TK-0001',
            'nama_toko' => 'Toko Uji',
            'alamat' => 'Jl. Contoh No. 1',
            'status_verifikasi' => StatusVerifikasi::Menunggu,
        ]);
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pengguna/{$akunToko->id}/aktifkan")->assertStatus(409);

        $this->assertFalse($akunToko->fresh()->is_active);
    }
}
