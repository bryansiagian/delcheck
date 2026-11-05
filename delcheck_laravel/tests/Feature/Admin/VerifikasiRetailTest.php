<?php

namespace Tests\Feature\Admin;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Models\Retailer;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;
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

    public function test_admin_tidak_dapat_melihat_daftar_pendaftar(): void
    {
        $this->buatPendaftar('a@toko.test');
        $this->buatPendaftar('b@toko.test');
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson('/api/admin/pendaftaran-retail')
            ->assertForbidden();
    }

    public function test_sales_dapat_melihat_daftar_dan_detail_pendaftar(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $this->getJson('/api/admin/pendaftaran-retail')->assertOk()
            ->assertJsonPath('data.items.0.id', $retailer->id);
        $this->getJson("/api/admin/pendaftaran-retail/{$retailer->id}")->assertOk()
            ->assertJsonPath('data.id', $retailer->id)
            ->assertJsonPath('data.status_verifikasi', 'menunggu');
    }

    public function test_admin_tidak_dapat_melihat_detail_pendaftar(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson("/api/admin/pendaftaran-retail/{$retailer->id}")->assertForbidden();
    }

    public function test_admin_ditolak_di_semua_endpoint_verifikasi_tanpa_mengubah_data(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson('/api/admin/pendaftaran-retail')->assertForbidden();
        $this->getJson("/api/admin/pendaftaran-retail/{$retailer->id}")->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")
            ->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Tidak sesuai'])
            ->assertForbidden();
        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'menunggu',
        ]);
        $this->assertDatabaseHas('users', [
            'id' => $retailer->user_id,
            'is_active' => false,
        ]);
    }

    public function test_hanya_sales_memiliki_permission_keputusan_verifikasi(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $this->assertFalse($admin->can('retailer.lihat-daftar'));
        $this->assertFalse($admin->can('retailer.verifikasi'));
        $sales = $this->buatUser(Peran::Sales);
        $this->assertTrue($sales->can('retailer.lihat-daftar'));
        $this->assertTrue($sales->can('retailer.verifikasi'));

        foreach ([Peran::Retail, Peran::Warehouse] as $role) {
            $user = $this->buatUser($role);
            $this->assertFalse($user->can('retailer.lihat-daftar'), $role->value);
            $this->assertFalse($user->can('retailer.verifikasi'), $role->value);
        }
    }

    public function test_seeder_tidak_menghapus_permission_lain_dari_role(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $permissionLain = Permission::findOrCreate('akses.lain', 'web');
        $admin->givePermissionTo($permissionLain);

        $this->seed(RolePermissionSeeder::class);

        $this->assertTrue($admin->fresh()->can('akses.lain'));
        $this->assertFalse($admin->fresh()->can('retailer.lihat-daftar'));
        $this->assertFalse($admin->fresh()->can('retailer.verifikasi'));
    }

    public function test_retail_tidak_boleh_mengakses_verifikasi(): void
    {
        Sanctum::actingAs($this->buatPendaftar()->user);

        $this->getJson('/api/admin/pendaftaran-retail')
            ->assertForbidden()
            ->assertJsonPath('kode', 'TIDAK_PUNYA_AKSES');
    }

    public function test_warehouse_tidak_dapat_membaca_atau_memproses_verifikasi(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->getJson('/api/admin/pendaftaran-retail')->assertForbidden();
        $this->getJson("/api/admin/pendaftaran-retail/{$retailer->id}")->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Tidak sesuai'])
            ->assertForbidden();

        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'menunggu',
        ]);
        $this->assertDatabaseHas('users', [
            'id' => $retailer->user_id,
            'is_active' => false,
        ]);
    }

    public function test_retail_tidak_dapat_melihat_detail_atau_memproses_verifikasi(): void
    {
        $retailer = $this->buatPendaftar('pendaftar-uji@toko.test');
        Sanctum::actingAs($retailer->user);

        $this->getJson("/api/admin/pendaftaran-retail/{$retailer->id}")->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")->assertForbidden();
        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Tidak sesuai'])
            ->assertForbidden();
        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'menunggu',
        ]);
        $this->assertDatabaseHas('users', [
            'id' => $retailer->user_id,
            'is_active' => false,
        ]);
    }

    public function test_tanpa_login_ditolak(): void
    {
        $this->getJson('/api/admin/pendaftaran-retail')->assertUnauthorized();
    }

    /** Menyetujui TANPA memilih sales (retail tidak terikat ke satu sales). */
    public function test_sales_menyetujui_tanpa_memilih_sales_dan_dicatat_sebagai_petugas(): void
    {
        $sales = $this->buatUser(Peran::Sales);
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($sales);

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'disetujui');

        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'disetujui',
            'diverifikasi_oleh' => $sales->id,
        ]);
        $this->assertTrue($retailer->user->fresh()->is_active);
        $this->assertDatabaseMissing('sales_assignments', [
            'retailer_id' => $retailer->id,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'auditable_id' => $retailer->id,
            'aksi' => 'verifikasi_disetujui',
            'user_id' => $sales->id,
        ]);

        // Setelah disetujui, Retail bisa login
        $this->postJson('/api/auth/login', ['email' => 'toko@baru.test', 'password' => 'rahasia123'])
            ->assertOk();
    }

    /** sales_id opsional, tetapi kalau dikirim tetap harus user Sales. */
    public function test_setujui_dengan_user_yang_bukan_sales_ditolak(): void
    {
        $retailer = $this->buatPendaftar();
        $warehouse = $this->buatUser(Peran::Warehouse);
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui", ['sales_id' => $warehouse->id])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['sales_id']);

        $this->assertDatabaseHas('retailers', ['id' => $retailer->id, 'status_verifikasi' => 'menunggu']);
    }

    public function test_pendaftaran_tidak_bisa_diproses_dua_kali(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $url = "/api/admin/pendaftaran-retail/{$retailer->id}/setujui";
        $this->postJson($url)->assertOk();

        $this->postJson($url)
            ->assertStatus(409)
            ->assertJsonPath('kode', 'PENDAFTARAN_SUDAH_DIPROSES');
    }

    public function test_tolak_wajib_alasan(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['alasan']);
    }

    public function test_sales_menolak_dengan_alasan_dan_dicatat_sebagai_petugas(): void
    {
        $sales = $this->buatUser(Peran::Sales);
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($sales);

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Data toko tidak valid'])
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'ditolak');

        $this->assertDatabaseHas('audit_logs', [
            'auditable_id' => $retailer->id,
            'aksi' => 'verifikasi_ditolak',
            'alasan' => 'Data toko tidak valid',
            'user_id' => $sales->id,
        ]);
        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'diverifikasi_oleh' => $sales->id,
            'status_verifikasi' => 'ditolak',
        ]);

        $this->postJson('/api/auth/login', ['email' => 'toko@baru.test', 'password' => 'rahasia123'])
            ->assertStatus(403)
            ->assertJsonPath('kode', 'AKUN_DITOLAK');
    }

    /** Pendaftaran yang sudah ditolak bisa disetujui ulang oleh Sales. */
    public function test_sales_menyetujui_ulang_pendaftaran_yang_ditolak(): void
    {
        $sales = $this->buatUser(Peran::Sales);
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($sales);

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Foto toko buram'])
            ->assertOk();
        $this->assertFalse($retailer->user->fresh()->is_active);

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")
            ->assertOk()
            ->assertJsonPath('data.status_verifikasi', 'disetujui');

        $this->assertDatabaseHas('retailers', [
            'id' => $retailer->id,
            'status_verifikasi' => 'disetujui',
            'alasan_ditolak' => null,
            'diverifikasi_oleh' => $sales->id,
        ]);
        $this->assertTrue($retailer->user->fresh()->is_active);

        // Setelah disetujui ulang, Retail bisa login
        $this->postJson('/api/auth/login', ['email' => 'toko@baru.test', 'password' => 'rahasia123'])
            ->assertOk();
    }

    /** Yang sudah disetujui tidak bisa ditolak lewat endpoint ini. */
    public function test_pendaftaran_yang_sudah_disetujui_tidak_bisa_ditolak(): void
    {
        $retailer = $this->buatPendaftar();
        Sanctum::actingAs($this->buatUser(Peran::Sales));

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/setujui")->assertOk();

        $this->postJson("/api/admin/pendaftaran-retail/{$retailer->id}/tolak", ['alasan' => 'Salah klik'])
            ->assertStatus(409)
            ->assertJsonPath('kode', 'PENDAFTARAN_SUDAH_DIPROSES');
    }

    public function test_daftar_sales_hanya_berisi_sales_aktif(): void
    {
        $salesAktif = $this->buatUser(Peran::Sales, ['is_active' => true]);
        $salesNonaktif = $this->buatUser(Peran::Sales, ['is_active' => false]);

        Sanctum::actingAs($this->buatUser(Peran::Admin));
        $this->getJson('/api/admin/sales')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $salesAktif->id)
            ->assertJsonMissing(['id' => $salesNonaktif->id]);

        Sanctum::actingAs($salesAktif);
        $this->getJson('/api/admin/sales')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $salesAktif->id)
            ->assertJsonMissing(['id' => $salesNonaktif->id]);
    }
}
