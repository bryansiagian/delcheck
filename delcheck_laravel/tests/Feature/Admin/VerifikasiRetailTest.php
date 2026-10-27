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

class VerifikasiRetailTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    private function buatUser(Peran $peran, array $atribut = []): User
    {
        $user = User::factory()->create($atribut);
        $user->assignRole($peran->value);

        return $user;
    }

    private function buatPendaftar(string $email = 'toko@baru.test'): Retailer
    {
        $user = $this->buatUser(Peran::Retail, [
            'email' => $email,
            'password' => 'rahasia123',
            'is_active' => false,
        ]);

        return Retailer::create([
            'user_id' => $user->id,
            'kode' => 'RTL-'.str_pad((string) $user->id, 6, '0', STR_PAD_LEFT),
            'nama_toko' => 'Toko Baru',
            'alamat' => 'Jl. Baru',
            'status_verifikasi' => StatusVerifikasi::Menunggu,
        ]);
    }

    public function test_admin_melihat_daftar_pendaftar_yang_menunggu(): void
    {
        $this->buatPendaftar('a@toko.test');
        $this->buatPendaftar('b@toko.test');
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson('/api/admin/pendaftaran-retail')
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.meta.total', 2);
    }

    public function test_retail_tidak_boleh_mengakses_verifikasi(): void
    {
        Sanctum::actingAs($this->buatPendaftar()->user);

        $this->getJson('/api/admin/pendaftaran-retail')
            ->assertForbidden()
            ->assertJsonPath('kode', 'TIDAK_PUNYA_AKSES');
    }

    public function test_tanpa_login_ditolak(): void
    {
        $this->getJson('/api/admin/pendaftaran-retail')->assertUnauthorized();
    }

    public function test_admin_menyetujui_dan_menugaskan_sales(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $sales = $this->buatUser(Peran::Sales);
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui", ['sales_id' => $sales->id])
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'disetujui');

        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'disetujui',
            'diverifikasi_oleh' => $admin->id,
        ]);
        $this->assertTrue($retailer->user->fresh()->is_active);
        $this->assertDatabaseHas('sales_assignments', [
            'sales_id' => $sales->id,
            'retailer_id' => $retailer->id,
            'is_active' => 1,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'auditable_id' => $retailer->id,
            'aksi' => 'verifikasi_disetujui',
            'user_id' => $admin->id,
        ]);

        // Setelah disetujui, Retail bisa login
        $this->postJson('/api/auth/login', ['email' => 'toko@baru.test', 'password' => 'rahasia123'])
            ->assertOk();
    }

    public function test_setujui_dengan_user_yang_bukan_sales_ditolak(): void
    {
        $retailer = $this->buatPendaftar();
        $warehouse = $this->buatUser(Peran::Warehouse);
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui", ['sales_id' => $warehouse->id])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['sales_id']);

        $this->assertDatabaseHas('retailers', ['id' => $retailer->id, 'status_verifikasi' => 'menunggu']);
    }

    public function test_pendaftaran_tidak_bisa_diproses_dua_kali(): void
    {
        $sales = $this->buatUser(Peran::Sales);
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $url = "/api/admin/pendaftaran-retail/{$retailer->id}/setujui";
        $this->postJson($url, ['sales_id' => $sales->id])->assertOk();

        $this->postJson($url, ['sales_id' => $sales->id])
            ->assertStatus(409)
            ->assertJsonPath('kode', 'PENDAFTARAN_SUDAH_DIPROSES');
    }

    public function test_tolak_wajib_alasan(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['alasan']);
    }

    public function test_tolak_dengan_alasan_lalu_login_ditolak(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Data toko tidak valid'])
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'ditolak');

        $this->assertDatabaseHas('audit_logs', [
            'auditable_id' => $retailer->id,
            'aksi' => 'verifikasi_ditolak',
            'alasan' => 'Data toko tidak valid',
        ]);

        $this->postJson('/api/auth/login', ['email' => 'toko@baru.test', 'password' => 'rahasia123'])
            ->assertStatus(403)
            ->assertJsonPath('kode', 'AKUN_DITOLAK');
    }

    public function test_daftar_sales_hanya_berisi_sales_aktif(): void
    {
        $this->buatUser(Peran::Sales, ['is_active' => true]);
        $this->buatUser(Peran::Sales, ['is_active' => false]);
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson('/api/admin/sales')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }
}
