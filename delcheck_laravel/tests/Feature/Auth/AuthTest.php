<?php

namespace Tests\Feature\Auth;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Models\Retailer;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    private function dataRegister(array $override = []): array
    {
        return array_merge([
            'name' => 'Budi Santoso',
            'email' => 'budi@toko.test',
            'password' => 'rahasia123',
            'nama_toko' => 'Toko Budi',
            'alamat' => 'Jl. Merdeka No. 1, Balige',
        ], $override);
    }

    private function buatRetail(StatusVerifikasi $status = StatusVerifikasi::Disetujui): User
    {
        $user = User::factory()->create([
            'email' => 'retail@toko.test',
            'phone' => '081234567890',
            'password' => 'rahasia123',
            'is_active' => $status === StatusVerifikasi::Disetujui,
        ]);
        $user->assignRole(Peran::Retail->value);

        Retailer::create([
            'user_id' => $user->id,
            'kode' => 'RTL-000001',
            'nama_toko' => 'Toko Test',
            'alamat' => 'Jl. Test',
            'status_verifikasi' => $status,
        ]);

        return $user;
    }

    // ---------------------------------------------------------- register

    public function test_guest_dapat_mendaftar_sebagai_retail(): void
    {
        $this->postJson('/api/auth/register', $this->dataRegister())
            ->assertCreated()
            ->assertJsonPath('success', true);

        $user = User::where('email', 'budi@toko.test')->firstOrFail();

        $this->assertFalse($user->is_active);
        $this->assertTrue($user->hasRole('retail'));
        $this->assertDatabaseHas('retailers', [
            'user_id' => $user->id,
            'nama_toko' => 'Toko Budi',
            'status_verifikasi' => 'menunggu',
            'kode' => sprintf('RTL-%06d', $user->retailer->id),
        ]);
    }

    public function test_register_tidak_menerima_peran_dari_request(): void
    {
        $this->postJson('/api/auth/register', $this->dataRegister(['role' => 'admin']))
            ->assertCreated();

        $user = User::where('email', 'budi@toko.test')->firstOrFail();

        $this->assertTrue($user->hasRole('retail'));
        $this->assertFalse($user->hasRole('admin'));
    }

    public function test_register_wajib_email_atau_telepon(): void
    {
        $this->postJson('/api/auth/register', $this->dataRegister(['email' => null]))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email', 'phone']);
    }

    public function test_register_menormalkan_nomor_telepon(): void
    {
        $this->postJson('/api/auth/register', $this->dataRegister([
            'email' => null,
            'phone' => '0812-3456-7890',
        ]))->assertCreated();

        $this->assertDatabaseHas('users', ['phone' => '6281234567890']);
    }

    public function test_register_menolak_email_yang_sudah_dipakai(): void
    {
        $this->buatRetail();

        $this->postJson('/api/auth/register', $this->dataRegister(['email' => 'retail@toko.test']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    // ------------------------------------------------------------- login

    public function test_login_dengan_email_berhasil(): void
    {
        $this->buatRetail();

        $this->postJson('/api/auth/login', [
            'email' => 'retail@toko.test',
            'password' => 'rahasia123',
        ])
            ->assertOk()
            ->assertJsonStructure(['success', 'message', 'data' => ['token', 'token_type', 'user' => ['id', 'roles', 'permissions']]]);
    }

    public function test_login_dengan_telepon_berhasil(): void
    {
        $this->buatRetail();

        $this->postJson('/api/auth/login', [
            'phone' => '0812 3456 7890',
            'password' => 'rahasia123',
        ])->assertOk();
    }

    public function test_login_dengan_email_dan_telepon_sekaligus_ditolak(): void
    {
        $this->buatRetail();

        $this->postJson('/api/auth/login', [
            'email' => 'retail@toko.test',
            'phone' => '081234567890',
            'password' => 'rahasia123',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['login']);
    }

    public function test_login_password_salah(): void
    {
        $this->buatRetail();

        $this->postJson('/api/auth/login', [
            'email' => 'retail@toko.test',
            'password' => 'salah-total',
        ])
            ->assertStatus(401)
            ->assertJsonPath('kode', 'KREDENSIAL_SALAH');
    }

    public function test_login_retail_yang_belum_diverifikasi_ditolak(): void
    {
        $this->buatRetail(StatusVerifikasi::Menunggu);

        $this->postJson('/api/auth/login', [
            'email' => 'retail@toko.test',
            'password' => 'rahasia123',
        ])
            ->assertStatus(403)
            ->assertJsonPath('kode', 'AKUN_MENUNGGU_VERIFIKASI');
    }

    // ------------------------------------------------------ logout & me

    public function test_logout_mencabut_token(): void
    {
        $this->buatRetail();

        $token = $this->postJson('/api/auth/login', [
            'email' => 'retail@toko.test',
            'password' => 'rahasia123',
        ])->json('data.token');

        $this->assertDatabaseCount('personal_access_tokens', 1);

        $this->withToken($token)->postJson('/api/auth/logout')->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_me_mengembalikan_peran_user(): void
    {
        Sanctum::actingAs($this->buatRetail());

        $this->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('data.roles.0', 'retail')
            ->assertJsonPath('data.retailer.status_verifikasi', 'disetujui');
    }

    public function test_me_tanpa_token_ditolak(): void
    {
        $this->getJson('/api/auth/me')->assertUnauthorized();
    }
}
