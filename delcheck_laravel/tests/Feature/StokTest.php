<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Models\Produk;
use App\Models\StokProduk;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StokTest extends TestCase
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

    /** Buat produk; jika $stok diisi, baris stoknya ikut dibuat. */
    private function buatProduk(array $override = [], ?int $stok = null): Produk
    {
        $this->urut++;

        $produk = Produk::create(array_merge([
            'kode' => 'SKU-'.str_pad((string) $this->urut, 3, '0', STR_PAD_LEFT),
            'nama' => 'Produk '.$this->urut,
            'satuan' => 'pcs',
            'harga' => 10000,
            'stok_minimum' => 0,
            'is_active' => true,
        ], $override));

        if ($stok !== null) {
            StokProduk::create(['produk_id' => $produk->id, 'jumlah' => $stok]);
        }

        return $produk;
    }

    // ------------------------------------------------------------ tambah

    public function test_warehouse_dapat_menambah_stok(): void
    {
        $produk = $this->buatProduk();
        $warehouse = $this->buatUser(Peran::Warehouse);
        Sanctum::actingAs($warehouse);

        $this->postJson("/api/stok/{$produk->id}/mutasi", [
            'tipe' => 'masuk',
            'jumlah' => 50,
            'alasan' => 'Barang datang dari pemasok',
        ])
            ->assertCreated()
            ->assertJsonPath('data.jumlah', 50)
            ->assertJsonPath('data.habis', false);

        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 50]);
        $this->assertDatabaseHas('mutasi_stok', [
            'produk_id' => $produk->id,
            'tipe' => 'masuk',
            'jumlah' => 50,
            'stok_sebelum' => 0,
            'stok_sesudah' => 50,
            'dibuat_oleh' => $warehouse->id,
        ]);
    }

    public function test_alasan_opsional_saat_menambah(): void
    {
        $produk = $this->buatProduk();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'masuk', 'jumlah' => 5])
            ->assertCreated();
    }

    // ----------------------------------------------------------- kurangi

    public function test_admin_dapat_mengurangi_stok(): void
    {
        $produk = $this->buatProduk([], 50);
        $admin = $this->buatUser(Peran::Admin);
        Sanctum::actingAs($admin);

        $this->postJson("/api/stok/{$produk->id}/mutasi", [
            'tipe' => 'keluar',
            'jumlah' => 20,
            'alasan' => 'Barang rusak',
        ])
            ->assertCreated()
            ->assertJsonPath('data.jumlah', 30);

        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 30]);
        $this->assertDatabaseHas('mutasi_stok', [
            'produk_id' => $produk->id,
            'tipe' => 'keluar',
            'jumlah' => -20,
            'stok_sebelum' => 50,
            'stok_sesudah' => 30,
            'alasan' => 'Barang rusak',
            'dibuat_oleh' => $admin->id,
        ]);
    }

    public function test_stok_tidak_boleh_negatif(): void
    {
        $produk = $this->buatProduk([], 5);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson("/api/stok/{$produk->id}/mutasi", [
            'tipe' => 'keluar',
            'jumlah' => 10,
            'alasan' => 'Salah hitung',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['jumlah']);

        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 5]);
        $this->assertDatabaseCount('mutasi_stok', 0);
    }

    public function test_alasan_wajib_saat_mengurangi(): void
    {
        $produk = $this->buatProduk([], 50);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'keluar', 'jumlah' => 5])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['alasan']);
    }

    // -------------------------------------------------------- validasi

    public function test_jumlah_minimal_satu_dan_tipe_valid(): void
    {
        $produk = $this->buatProduk();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'masuk', 'jumlah' => 0])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['jumlah']);

        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'lainnya', 'jumlah' => 5])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['tipe']);
    }

    // ----------------------------------------------------------- akses

    public function test_retail_dan_sales_tidak_boleh_mengubah_stok(): void
    {
        $produk = $this->buatProduk();

        Sanctum::actingAs($this->buatUser(Peran::Retail));
        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'masuk', 'jumlah' => 5])
            ->assertForbidden()
            ->assertJsonPath('kode', 'TIDAK_PUNYA_AKSES');

        Sanctum::actingAs($this->buatUser(Peran::Sales));
        $this->getJson('/api/stok')->assertForbidden();

        $this->assertDatabaseCount('mutasi_stok', 0);
    }

    public function test_tanpa_login_ditolak(): void
    {
        $this->getJson('/api/stok')->assertUnauthorized();
    }

    // ------------------------------------------------------------ daftar

    public function test_daftar_stok_menampilkan_jumlah_dan_penanda(): void
    {
        $this->buatProduk(['kode' => 'AAA', 'stok_minimum' => 10], 5);   // menipis
        $this->buatProduk(['kode' => 'BBB', 'stok_minimum' => 10], 50);  // aman
        $this->buatProduk(['kode' => 'CCC', 'stok_minimum' => 10]);      // belum ada baris stok = habis
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $respons = $this->getJson('/api/stok')->assertOk()->assertJsonCount(3, 'data.items');

        $item = collect($respons->json('data.items'))->keyBy('kode');
        $this->assertSame(5, $item['AAA']['jumlah']);
        $this->assertTrue($item['AAA']['menipis']);
        $this->assertFalse($item['BBB']['menipis']);
        $this->assertSame(0, $item['CCC']['jumlah']);
        $this->assertTrue($item['CCC']['habis']);
    }

    public function test_filter_stok_menipis(): void
    {
        $this->buatProduk(['kode' => 'AAA', 'stok_minimum' => 10], 5);
        $this->buatProduk(['kode' => 'BBB', 'stok_minimum' => 10], 50);
        Sanctum::actingAs($this->buatUser(Peran::Admin));

        $this->getJson('/api/stok?status=menipis')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.kode', 'AAA');
    }

    public function test_pencarian_stok(): void
    {
        $this->buatProduk(['kode' => 'MIE-01', 'nama' => 'Mie Goreng'], 10);
        $this->buatProduk(['kode' => 'AIR-01', 'nama' => 'Air Mineral'], 10);
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->getJson('/api/stok?q=mie')->assertOk()->assertJsonCount(1, 'data.items');
    }

    // ----------------------------------------------------------- riwayat

    public function test_riwayat_mutasi_terbaru_dulu(): void
    {
        $produk = $this->buatProduk();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'masuk', 'jumlah' => 10])->assertCreated();
        $this->postJson("/api/stok/{$produk->id}/mutasi", ['tipe' => 'keluar', 'jumlah' => 3, 'alasan' => 'Rusak'])->assertCreated();

        $this->getJson("/api/stok/{$produk->id}/mutasi")
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.0.jumlah', -3)
            ->assertJsonPath('data.items.1.jumlah', 10);
    }

    public function test_stok_produk_yang_dihapus_tidak_ditemukan(): void
    {
        $produk = $this->buatProduk([], 5);
        $produk->delete();
        Sanctum::actingAs($this->buatUser(Peran::Warehouse));

        $this->getJson("/api/stok/{$produk->id}")->assertNotFound();
    }
}
