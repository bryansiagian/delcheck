<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Models\Produk;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProdukTest extends TestCase
{
    use RefreshDatabase;

    private int $urut = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    private function buatUser(Peran $peran): User
    {
        $user = User::factory()->create();
        $user->assignRole($peran->value);

        return $user;
    }

    private function dataProduk(array $override = []): array
    {
        return array_merge([
            'kode' => 'SKU-001',
            'nama' => 'Mie Instan Goreng',
            'satuan' => 'dus',
            'harga' => 95000,
            'stok_minimum' => 10,
            'deskripsi' => 'Isi 40 bungkus',
            'is_active' => true,
        ], $override);
    }

    private function buatProduk(array $override = []): Produk
    {
        $this->urut++;

        return Produk::create(array_merge([
            'kode' => 'SKU-'.str_pad((string) $this->urut, 3, '0', STR_PAD_LEFT),
            'nama' => 'Produk '.$this->urut,
            'satuan' => 'pcs',
            'harga' => 10000,
            'is_active' => true,
        ], $override));
    }

    // ------------------------------------------------------------ tambah

    public function test_warehouse_dapat_menambah_produk(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson('/api/produk', $this->dataProduk(['kode' => 'sku-001']))
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.kode', 'SKU-001') // dinormalkan ke huruf besar
            ->assertJsonPath('data.is_active', true);

        $this->assertDatabaseHas('produk', ['kode' => 'SKU-001', 'nama' => 'Mie Instan Goreng']);
    }

    public function test_admin_dapat_menambah_produk(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->postJson('/api/produk', $this->dataProduk())->assertCreated();
    }

    public function test_retail_dan_sales_tidak_boleh_menambah_produk(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Retail));
        $this->postJson('/api/produk', $this->dataProduk())
            ->assertForbidden()
            ->assertJsonPath('kode', 'TIDAK_PUNYA_AKSES');

        Sanctum::actingAs($this->buatUser(Peran::Sales));
        $this->postJson('/api/produk', $this->dataProduk())->assertForbidden();

        $this->assertDatabaseCount('produk', 0);
    }

    public function test_tanpa_login_ditolak(): void
    {
        $this->getJson('/api/produk')->assertUnauthorized();
        $this->postJson('/api/produk', $this->dataProduk())->assertUnauthorized();
    }

    public function test_field_wajib_divalidasi(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson('/api/produk', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['kode', 'nama', 'satuan', 'harga']);
    }

    public function test_kode_harus_unik(): void
    {
        $this->buatProduk(['kode' => 'SKU-001']);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson('/api/produk', $this->dataProduk(['kode' => 'sku-001']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['kode']);
    }

    public function test_kode_tidak_boleh_mengandung_spasi(): void
    {
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson('/api/produk', $this->dataProduk(['kode' => 'SKU 001']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['kode']);
    }

    // -------------------------------------------------------------- ubah

    public function test_warehouse_dapat_mengubah_produk(): void
    {
        $produk = $this->buatProduk(['kode' => 'SKU-001']);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        // Kode yang sama milik produk itu sendiri tidak dianggap duplikat.
        $this->putJson("/api/produk/{$produk->id}", $this->dataProduk(['harga' => 20000, 'is_active' => false]))
            ->assertOk()
            ->assertJsonPath('data.harga', 20000)
            ->assertJsonPath('data.is_active', false);

        $this->assertDatabaseHas('produk', ['id' => $produk->id, 'is_active' => 0]);
    }

    public function test_ubah_tidak_boleh_memakai_kode_produk_lain(): void
    {
        $this->buatProduk(['kode' => 'SKU-001']);
        $lain = $this->buatProduk(['kode' => 'SKU-002']);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->putJson("/api/produk/{$lain->id}", $this->dataProduk(['kode' => 'SKU-001']))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['kode']);
    }

    // ------------------------------------------------------------- hapus

    public function test_hapus_produk_adalah_soft_delete(): void
    {
        $produk = $this->buatProduk();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->deleteJson("/api/produk/{$produk->id}")->assertOk();

        $this->assertSoftDeleted('produk', ['id' => $produk->id]);
        $this->getJson("/api/produk/{$produk->id}")->assertNotFound();
    }

    public function test_retail_tidak_boleh_menghapus_produk(): void
    {
        $produk = $this->buatProduk();
        Sanctum::actingAs($this->buatUser(Peran::Retail));

        $this->deleteJson("/api/produk/{$produk->id}")->assertForbidden();
        $this->assertDatabaseHas('produk', ['id' => $produk->id, 'deleted_at' => null]);
    }

    // ------------------------------------------------------------ daftar

    public function test_warehouse_melihat_semua_produk_termasuk_nonaktif(): void
    {
        $this->buatProduk(['is_active' => true]);
        $this->buatProduk(['is_active' => false]);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->getJson('/api/produk')
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.meta.total', 2);

        $this->getJson('/api/produk?status=nonaktif')
            ->assertOk()
            ->assertJsonCount(1, 'data.items');
    }

    public function test_retail_hanya_melihat_produk_aktif(): void
    {
        $this->buatProduk(['is_active' => true]);
        $nonaktif = $this->buatProduk(['is_active' => false]);
        Sanctum::actingAs($this->buatUser(Peran::Retail));

        $this->getJson('/api/produk')
            ->assertOk()
            ->assertJsonCount(1, 'data.items');

        $this->getJson("/api/produk/{$nonaktif->id}")->assertNotFound();
    }

    public function test_pencarian_berdasarkan_nama_atau_kode(): void
    {
        $this->buatProduk(['kode' => 'MIE-01', 'nama' => 'Mie Goreng']);
        $this->buatProduk(['kode' => 'AIR-01', 'nama' => 'Air Mineral']);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->getJson('/api/produk?q=mie')->assertOk()->assertJsonCount(1, 'data.items');
        $this->getJson('/api/produk?q=AIR-01')->assertOk()->assertJsonCount(1, 'data.items');
    }
}
