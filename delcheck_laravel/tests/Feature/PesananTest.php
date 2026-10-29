<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Models\Pesanan;
use App\Models\Produk;
use App\Models\Retailer;
use App\Models\StokProduk;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PesananTest extends TestCase
{
    use RefreshDatabase;

    private int $urut = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
    }

    // ----------------------------------------------------------- pembantu

    private function buatUser(Peran $peran): User
    {
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole($peran->value);

        return $user;
    }

    private function buatRetail(string $email = 'retail@toko.test', string $namaToko = 'Toko A'): User
    {
        $user = $this->buatUser(Peran::Retail);
        $user->update(['email' => $email]);

        Retailer::create([
            'user_id' => $user->id,
            'kode' => 'RTL-'.str_pad((string) $user->id, 6, '0', STR_PAD_LEFT),
            'nama_toko' => $namaToko,
            'alamat' => 'Jl. Test',
            'status_verifikasi' => StatusVerifikasi::Disetujui,
        ]);

        return $user->fresh();
    }

    private function buatProduk(int $stok, array $override = []): Produk
    {
        $this->urut++;

        $produk = Produk::create(array_merge([
            'kode' => 'SKU-'.str_pad((string) $this->urut, 3, '0', STR_PAD_LEFT),
            'nama' => 'Produk '.$this->urut,
            'satuan' => 'dus',
            'harga' => 10000,
            'stok_minimum' => 0,
            'is_active' => true,
        ], $override));

        StokProduk::create(['produk_id' => $produk->id, 'jumlah' => $stok]);

        return $produk;
    }

    /** Retail membuat pesanan lewat API dan mengembalikan id-nya. */
    private function pesan(User $retail, array $items): int
    {
        Sanctum::actingAs($retail);

        return $this->postJson('/api/pesanan', ['items' => $items])
            ->assertCreated()
            ->json('data.id');
    }

    private function sebagai(Peran $peran): User
    {
        $user = $this->buatUser($peran);
        Sanctum::actingAs($user);

        return $user;
    }

    // -------------------------------------------------------- Retail: buat

    public function test_retail_membuat_pesanan(): void
    {
        $retail = $this->buatRetail();
        $mie = $this->buatProduk(100, ['nama' => 'Mie', 'harga' => 10000]);
        $air = $this->buatProduk(100, ['nama' => 'Air', 'harga' => 5000]);
        Sanctum::actingAs($retail);

        $res = $this->postJson('/api/pesanan', [
            'items' => [
                ['produk_id' => $mie->id, 'qty' => 2],
                ['produk_id' => $air->id, 'qty' => 3],
            ],
            'catatan' => 'Kirim pagi',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'menunggu_konfirmasi_sales')
            ->assertJsonPath('data.sumber', 'retail')
            ->assertJsonCount(2, 'data.items');

        $this->assertEquals(35000, $res->json('data.total'));
        $this->assertMatchesRegularExpression('/^PSN-\d{8}-\d{5}$/', $res->json('data.nomor'));

        $this->assertDatabaseHas('pesanan', [
            'retailer_id' => $retail->retailer->id,
            'dibuat_oleh' => $retail->id,
            'status' => 'menunggu_konfirmasi_sales',
        ]);
        $this->assertDatabaseHas('item_pesanan', ['produk_id' => $mie->id, 'nama_produk' => 'Mie', 'qty' => 2]);

        // Stok belum berkurang saat pesanan dibuat.
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $mie->id, 'jumlah' => 100]);
    }

    public function test_harga_disalin_saat_pesanan_dibuat(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100, ['harga' => 10000]);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        $produk->update(['harga' => 99999]);

        $harga = $this->getJson("/api/pesanan/{$id}")->assertOk()->json('data.items.0.harga');
        $this->assertEquals(10000, $harga);
    }

    public function test_pesan_melebihi_stok_ditolak(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(5);
        Sanctum::actingAs($retail);

        $this->postJson('/api/pesanan', ['items' => [['produk_id' => $produk->id, 'qty' => 10]]])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['items.0.qty']);

        $this->assertDatabaseCount('pesanan', 0);
    }

    public function test_produk_nonaktif_tidak_bisa_dipesan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10, ['is_active' => false]);
        Sanctum::actingAs($retail);

        $this->postJson('/api/pesanan', ['items' => [['produk_id' => $produk->id, 'qty' => 1]]])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['items.0.produk_id']);
    }

    public function test_validasi_item_pesanan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        Sanctum::actingAs($retail);

        $this->postJson('/api/pesanan', ['items' => []])->assertStatus(422);
        $this->postJson('/api/pesanan', ['items' => [['produk_id' => $produk->id, 'qty' => 0]]])->assertStatus(422);
        $this->postJson('/api/pesanan', ['items' => [
            ['produk_id' => $produk->id, 'qty' => 1],
            ['produk_id' => $produk->id, 'qty' => 2],
        ]])->assertStatus(422);

        $this->assertDatabaseCount('pesanan', 0);
    }

    public function test_sales_tidak_bisa_membuat_pesanan_toko(): void
    {
        $produk = $this->buatProduk(10);
        $this->sebagai(Peran::Sales);

        $this->postJson('/api/pesanan', ['items' => [['produk_id' => $produk->id, 'qty' => 1]]])
            ->assertForbidden()
            ->assertJsonPath('kode', 'TOKO_TIDAK_DITEMUKAN');
    }

    public function test_tanpa_login_ditolak(): void
    {
        $this->getJson('/api/pesanan')->assertUnauthorized();
        $this->postJson('/api/pesanan', [])->assertUnauthorized();
    }

    // ------------------------------------------------------------- daftar

    public function test_cakupan_daftar_pesanan_per_peran(): void
    {
        $a = $this->buatRetail('a@toko.test', 'Toko A');
        $b = $this->buatRetail('b@toko.test', 'Toko B');
        $produk = $this->buatProduk(100);

        $idA = $this->pesan($a, [['produk_id' => $produk->id, 'qty' => 1]]);
        $idB = $this->pesan($b, [['produk_id' => $produk->id, 'qty' => 1]]);

        // Retail hanya melihat pesanan tokonya sendiri.
        Sanctum::actingAs($a);
        $this->getJson('/api/pesanan')
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.id', $idA);
        $this->getJson("/api/pesanan/{$idB}")->assertNotFound();

        // Sales, Warehouse, dan Admin melihat semua.
        foreach ([Peran::Sales, Peran::Warehouse, Peran::Admin] as $peran) {
            $this->sebagai($peran);
            $this->getJson('/api/pesanan')->assertOk()->assertJsonCount(2, 'data.items');
        }
    }

    public function test_filter_status_dan_pencarian(): void
    {
        $a = $this->buatRetail('a@toko.test', 'Toko Maju');
        $b = $this->buatRetail('b@toko.test', 'Toko Jaya');
        $produk = $this->buatProduk(100);
        $idA = $this->pesan($a, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->pesan($b, [['produk_id' => $produk->id, 'qty' => 1]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$idA}/setujui")->assertOk();

        $this->getJson('/api/pesanan?status=dikonfirmasi')->assertOk()->assertJsonCount(1, 'data.items');
        $this->getJson('/api/pesanan?status=menunggu_konfirmasi_sales,dikonfirmasi')->assertOk()->assertJsonCount(2, 'data.items');
        $this->getJson('/api/pesanan?status=ngawur')->assertStatus(422);
        $this->getJson('/api/pesanan?q=Jaya')->assertOk()->assertJsonCount(1, 'data.items');
    }

    // -------------------------------------------------------------- Sales

    public function test_sales_menyetujui_pesanan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 2]]);

        $sales = $this->sebagai(Peran::Sales);

        $this->postJson("/api/pesanan/{$id}/setujui")
            ->assertOk()
            ->assertJsonPath('data.status', 'dikonfirmasi');

        $this->assertDatabaseHas('pesanan', [
            'id' => $id,
            'status' => 'dikonfirmasi',
            'sales_id' => $sales->id,
            'dikonfirmasi_oleh' => $sales->id,
        ]);

        // Tidak bisa diproses dua kali.
        $this->postJson("/api/pesanan/{$id}/setujui")
            ->assertStatus(409)
            ->assertJsonPath('kode', 'STATUS_PESANAN_TIDAK_VALID');
    }

    public function test_sales_menolak_pesanan_wajib_alasan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 2]]);

        $this->sebagai(Peran::Sales);

        $this->postJson("/api/pesanan/{$id}/tolak", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['alasan']);

        $this->postJson("/api/pesanan/{$id}/tolak", ['alasan' => 'Toko menunggak pembayaran'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak')
            ->assertJsonPath('data.alasan_ditolak', 'Toko menunggak pembayaran');

        // Pesanan yang ditolak tidak bisa disetujui lagi.
        $this->postJson("/api/pesanan/{$id}/setujui")->assertStatus(409);
    }

    public function test_hanya_sales_yang_boleh_menyetujui(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertForbidden();

        foreach ([Peran::Warehouse, Peran::Admin] as $peran) {
            $this->sebagai($peran);
            $this->postJson("/api/pesanan/{$id}/setujui")->assertForbidden();
        }

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'menunggu_konfirmasi_sales']);
    }

    // ----------------------------------------------------------- Pembatalan

    public function test_retail_membatalkan_pesanan_yang_menunggu(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        $this->postJson("/api/pesanan/{$id}/batalkan", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['alasan']);

        $this->postJson("/api/pesanan/{$id}/batalkan", ['alasan' => 'Salah pesan'])
            ->assertOk()
            ->assertJsonPath('data.status', 'dibatalkan');

        $this->assertDatabaseHas('pesanan', [
            'id' => $id,
            'status' => 'dibatalkan',
            'dibatalkan_oleh' => $retail->id,
            'alasan_batal' => 'Salah pesan',
        ]);
    }

    public function test_pesanan_yang_sudah_dikonfirmasi_tidak_bisa_dibatalkan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/batalkan", ['alasan' => 'Berubah pikiran'])
            ->assertStatus(409)
            ->assertJsonPath('kode', 'STATUS_PESANAN_TIDAK_VALID');
    }

    public function test_retail_lain_tidak_bisa_membatalkan_atau_menerima(): void
    {
        $a = $this->buatRetail('a@toko.test', 'Toko A');
        $b = $this->buatRetail('b@toko.test', 'Toko B');
        $produk = $this->buatProduk(100);
        $id = $this->pesan($a, [['produk_id' => $produk->id, 'qty' => 1]]);

        Sanctum::actingAs($b);
        $this->postJson("/api/pesanan/{$id}/batalkan", ['alasan' => 'Iseng'])->assertNotFound();
        $this->postJson("/api/pesanan/{$id}/terima")->assertNotFound();

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'menunggu_konfirmasi_sales']);
    }

    // ------------------------------------------------- Warehouse / Pengiriman

    public function test_warehouse_menyerahkan_ke_kurir_setelah_dikonfirmasi(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        $warehouse = $this->sebagai(Peran::Warehouse);

        // Belum dikonfirmasi Sales.
        $this->postJson("/api/pesanan/{$id}/proses")
            ->assertStatus(409)
            ->assertJsonPath('kode', 'STATUS_PESANAN_TIDAK_VALID');

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        // Sales tidak boleh memproses pengiriman.
        $this->postJson("/api/pesanan/{$id}/proses")->assertForbidden();

        Sanctum::actingAs($warehouse);
        $this->postJson("/api/pesanan/{$id}/proses")
            ->assertOk()
            ->assertJsonPath('data.status', 'diproses');

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diproses', 'diproses_oleh' => $warehouse->id]);
    }

    public function test_kirim_mengurangi_stok_dan_mencatat_pengiriman(): void
    {
        $retail = $this->buatRetail();
        $mie = $this->buatProduk(100, ['harga' => 10000]);
        $air = $this->buatProduk(50, ['harga' => 5000]);
        $id = $this->pesan($retail, [
            ['produk_id' => $mie->id, 'qty' => 2],
            ['produk_id' => $air->id, 'qty' => 10],
        ]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $admin = $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/kirim", [
            'nomor_surat_jalan' => 'SJ-001',
            'estimasi_tiba' => now()->addDays(2)->toDateString(),
            'catatan' => 'Kurir: Budi (JNE)',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'dikirim')
            ->assertJsonPath('data.pengiriman.nomor_surat_jalan', 'SJ-001')
            ->assertJsonPath('data.pengiriman.status', 'dikirim');

        $this->assertDatabaseHas('stok_produk', ['produk_id' => $mie->id, 'jumlah' => 98]);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $air->id, 'jumlah' => 40]);

        $this->assertDatabaseHas('mutasi_stok', [
            'produk_id' => $mie->id,
            'tipe' => 'keluar',
            'jumlah' => -2,
            'stok_sebelum' => 100,
            'stok_sesudah' => 98,
            'referensi_type' => Pesanan::class,
            'referensi_id' => $id,
            'dibuat_oleh' => $admin->id,
        ]);

        $this->assertDatabaseHas('pengiriman', [
            'pesanan_id' => $id,
            'status' => 'dikirim',
            'diperbarui_oleh' => $admin->id,
        ]);
        $this->assertNotNull(Pesanan::find($id)->dikirim_at);

        // Tidak bisa dikirim dua kali (stok tidak berkurang lagi).
        $this->postJson("/api/pesanan/{$id}/kirim", [])->assertStatus(409);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $mie->id, 'jumlah' => 98]);
    }

    public function test_kirim_setelah_diserahkan_ke_kurir(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 4]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $this->sebagai(Peran::Warehouse);
        $this->postJson("/api/pesanan/{$id}/proses")->assertOk();
        $this->postJson("/api/pesanan/{$id}/kirim", [])
            ->assertOk()
            ->assertJsonPath('data.status', 'dikirim');

        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 96]);
    }

    public function test_kirim_ditolak_jika_stok_tidak_cukup(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 5]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        // Stok berkurang setelah pesanan dibuat (mis. dipakai pesanan lain).
        StokProduk::where('produk_id', $produk->id)->update(['jumlah' => 2]);

        $this->sebagai(Peran::Warehouse);
        $this->postJson("/api/pesanan/{$id}/kirim", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['stok']);

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikonfirmasi']);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 2]);
        $this->assertDatabaseCount('pengiriman', 0);
        $this->assertDatabaseCount('mutasi_stok', 0);
    }

    public function test_estimasi_tiba_tidak_boleh_sebelum_tanggal_kirim(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $this->sebagai(Peran::Warehouse);
        $this->postJson("/api/pesanan/{$id}/kirim", [
            'tanggal_kirim' => now()->toDateString(),
            'estimasi_tiba' => now()->subDay()->toDateString(),
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['estimasi_tiba']);
    }

    public function test_retail_dan_sales_tidak_boleh_mengirim(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/kirim", [])->assertForbidden();

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/kirim", [])->assertForbidden();
    }

    // ------------------------------------------------------- Retail: terima

    public function test_retail_mengonfirmasi_pesanan_diterima(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

        // Belum dikirim: tidak bisa diterima.
        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")->assertStatus(409);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->sebagai(Peran::Warehouse);
        $this->postJson("/api/pesanan/{$id}/kirim", [])->assertOk();

        // Hanya Retail yang boleh mengonfirmasi (BR-10).
        $this->postJson("/api/pesanan/{$id}/terima")->assertForbidden();

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")
            ->assertOk()
            ->assertJsonPath('data.status', 'diterima')
            ->assertJsonPath('data.pengiriman.status', 'diterima');

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diterima', 'diterima_oleh' => $retail->id]);
        $this->assertDatabaseHas('pengiriman', ['pesanan_id' => $id, 'status' => 'diterima']);
    }

    // ------------------------------------------------------- Alur lengkap

    public function test_alur_lengkap_dari_pesan_sampai_diterima(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(20, ['harga' => 25000]);

        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 6]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $this->sebagai(Peran::Warehouse);
        $this->postJson("/api/pesanan/{$id}/proses")->assertOk();
        $this->postJson("/api/pesanan/{$id}/kirim", ['catatan' => 'Kurir toko'])->assertOk();

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")->assertOk();

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diterima']);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 14]);

        $detail = $this->getJson("/api/pesanan/{$id}")->assertOk();
        $this->assertEquals(150000, $detail->json('data.total'));
        $this->assertNotNull($detail->json('data.dikonfirmasi_at'));
        $this->assertNotNull($detail->json('data.diproses_at'));
        $this->assertNotNull($detail->json('data.dikirim_at'));
        $this->assertNotNull($detail->json('data.diterima_at'));
    }
}
