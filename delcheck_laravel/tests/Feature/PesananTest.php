<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Models\AuditLog;
use App\Models\MutasiStok;
use App\Models\Pengiriman;
use App\Models\Pesanan;
use App\Models\Produk;
use App\Models\Retailer;
use App\Models\StokProduk;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Role;
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

    private function dataPengiriman(array $override = []): array
    {
        return array_merge([
            'nama_pengemudi' => 'Budi Santoso',
            'telepon_pengemudi' => '081234567890',
            'nomor_kendaraan' => 'BK 1234 AB',
            'tanggal_kirim' => now()->toDateString(),
            'nomor_surat_jalan' => 'SJ-001',
            'catatan' => 'Rute utama',
        ], $override);
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
            if ($peran === Peran::Warehouse) {
                $this->getJson("/api/pesanan/{$idA}")
                    ->assertOk()
                    ->assertJsonPath('data.id', $idA);
            }
        }
    }

    public function test_permission_pesanan_admin_sales_dan_warehouse(): void
    {
        $admin = $this->buatUser(Peran::Admin);
        $sales = $this->buatUser(Peran::Sales);
        $warehouse = $this->buatUser(Peran::Warehouse);

        $this->assertTrue($admin->can('pesanan.lihat-semua'));
        $this->assertTrue($admin->can('pesanan.proses'));
        $this->assertTrue($admin->can('pengiriman.perbarui'));
        $this->assertTrue($admin->can('produk.kelola'));
        $this->assertTrue($admin->can('stok.kelola'));
        $this->assertFalse($admin->can('pesanan.konfirmasi'));

        $this->assertTrue($sales->can('pesanan.konfirmasi'));
        $this->assertFalse($sales->can('pesanan.proses'));
        $this->assertFalse($sales->can('pengiriman.perbarui'));

        $this->assertTrue($warehouse->can('pesanan.lihat-semua'));
        $this->assertFalse($warehouse->can('pesanan.proses'));
        $this->assertFalse($warehouse->can('pengiriman.perbarui'));
        $this->assertTrue($warehouse->can('produk.kelola'));
        $this->assertTrue($warehouse->can('stok.kelola'));
        $this->assertTrue($warehouse->can('retur.pantau-logistik'));
    }

    public function test_seeder_memindahkan_izin_proses_tanpa_menghapus_izin_warehouse_lain(): void
    {
        $warehouseRole = Role::findByName(Peran::Warehouse->value, 'web');
        $warehouseRole->givePermissionTo('pesanan.proses');
        $warehouseRole->givePermissionTo('pengiriman.perbarui');

        $this->seed(RolePermissionSeeder::class);

        $warehouse = $this->buatUser(Peran::Warehouse);
        $this->assertFalse($warehouse->can('pesanan.proses'));
        $this->assertFalse($warehouse->can('pengiriman.perbarui'));
        $this->assertTrue($warehouse->can('produk.kelola'));
        $this->assertTrue($warehouse->can('stok.kelola'));
        $this->assertTrue($warehouse->can('retur.pantau-logistik'));
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

    public function test_daftar_menyertakan_status_pengiriman_dan_mempertahankan_pagination(): void
    {
        $produk = $this->buatProduk(100);
        $retailers = [];
        $ids = [];
        foreach (['dikonfirmasi', 'kurir', 'jalan', 'diterima'] as $tahap) {
            $retail = $this->buatRetail("{$tahap}@toko.test", "Toko {$tahap}");
            $retailers[$tahap] = $retail;
            $ids[$tahap] = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        }

        $this->sebagai(Peran::Sales);
        foreach ($ids as $id) {
            $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        }

        $this->sebagai(Peran::Admin);
        foreach (['kurir', 'jalan', 'diterima'] as $tahap) {
            $this->postJson("/api/pesanan/{$ids[$tahap]}/catat-pengiriman", $this->dataPengiriman())
                ->assertOk();
        }
        foreach (['jalan', 'diterima'] as $tahap) {
            $this->postJson("/api/pesanan/{$ids[$tahap]}/tandai-jalan")->assertOk();
        }
        Sanctum::actingAs($retailers['diterima']);
        $this->postJson("/api/pesanan/{$ids['diterima']}/terima")->assertOk();

        $pageOne = $this->actingAs($this->buatUser(Peran::Admin))
            ->getJson('/api/pesanan?per_page=3')
            ->assertOk()
            ->assertJsonPath('data.meta.total', 4)
            ->assertJsonPath('data.meta.halaman', 1)
            ->assertJsonPath('data.meta.halaman_terakhir', 2);
        $pageTwo = $this->getJson('/api/pesanan?page=2&per_page=3')
            ->assertOk()
            ->assertJsonPath('data.meta.halaman', 2)
            ->assertJsonCount(1, 'data.items');

        $itemByStatus = collect([
            ...$pageOne->json('data.items'),
            ...$pageTwo->json('data.items'),
        ])->keyBy('status');

        foreach ([
            'dikonfirmasi' => null,
            'diproses' => 'kurir',
            'dikirim' => 'jalan',
            'diterima' => 'diterima',
        ] as $statusPesanan => $statusPengiriman) {
            $item = $itemByStatus->get($statusPesanan);
            $this->assertNotNull($item, "Daftar harus memuat pesanan {$statusPesanan}.");
            $this->assertArrayHasKey('pengiriman', $item);
            $this->assertSame($statusPengiriman, $item['pengiriman']['status'] ?? null);
        }

        $this->getJson("/api/pesanan/{$ids['diterima']}")
            ->assertOk()
            ->assertJsonPath('data.status', 'diterima')
            ->assertJsonPath('data.pengiriman.status', 'diterima');
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

    public function test_admin_mencatat_pengiriman_dan_mengurangi_stok_satu_kali(): void
    {
        $retail = $this->buatRetail();
        $mie = $this->buatProduk(100);
        $air = $this->buatProduk(50);
        $id = $this->pesan($retail, [
            ['produk_id' => $mie->id, 'qty' => 2],
            ['produk_id' => $air->id, 'qty' => 10],
        ]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
            ->assertForbidden();

        $admin = $this->sebagai(Peran::Admin);
        $response = $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman([
            'estimasi_tiba' => now()->addDays(2)->toDateString(),
        ]));
        $response->assertOk()
            ->assertJsonPath('data.status', 'diproses')
            ->assertJsonPath('data.pengiriman.status', 'kurir')
            ->assertJsonPath('data.pengiriman.nama_pengemudi', 'Budi Santoso')
            ->assertJsonPath('data.pengiriman.telepon_pengemudi', '081234567890')
            ->assertJsonPath('data.pengiriman.nomor_kendaraan', 'BK 1234 AB');

        $this->assertDatabaseHas('pesanan', [
            'id' => $id,
            'status' => 'diproses',
            'diproses_oleh' => $admin->id,
        ]);
        $this->assertNotNull(Pesanan::find($id)->diproses_at);
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
            'status' => 'kurir',
            'nama_pengemudi' => 'Budi Santoso',
            'telepon_pengemudi' => '081234567890',
            'nomor_kendaraan' => 'BK 1234 AB',
            'diperbarui_oleh' => $admin->id,
        ]);
        $this->assertSame(1, Pengiriman::where('pesanan_id', $id)->count());
        $this->assertDatabaseHas('audit_logs', [
            'auditable_type' => Pesanan::class,
            'auditable_id' => $id,
            'aksi' => 'pengiriman_dicatat',
            'status_dari' => 'dikonfirmasi',
            'status_ke' => 'diproses',
            'user_id' => $admin->id,
        ]);
        $auditCatat = AuditLog::where('aksi', 'pengiriman_dicatat')->firstOrFail();
        $this->assertNotNull($auditCatat->created_at);
        $this->assertSame($id, $auditCatat->meta['pesanan_id']);
        $this->assertSame($response->json('data.pengiriman.id'), $auditCatat->meta['pengiriman_id']);
        $this->assertNull($auditCatat->meta['status_pengiriman_dari']);
        $this->assertSame('kurir', $auditCatat->meta['status_pengiriman_ke']);

        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
            ->assertStatus(409);
        $this->assertSame(1, Pengiriman::where('pesanan_id', $id)->count());
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $mie->id, 'jumlah' => 98]);
    }

    public function test_admin_menandai_jalan_tanpa_pengiriman_baru_atau_pengurangan_stok(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 4]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $admin = $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertStatus(409);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
            ->assertOk();
        $stokSetelahCatat = (int) StokProduk::where('produk_id', $produk->id)->value('jumlah');
        $mutasiSetelahCatat = MutasiStok::where('referensi_type', Pesanan::class)
            ->where('referensi_id', $id)->count();

        $this->postJson("/api/pesanan/{$id}/tandai-jalan")
            ->assertOk()
            ->assertJsonPath('data.status', 'dikirim')
            ->assertJsonPath('data.pengiriman.status', 'jalan');

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikirim']);
        $this->assertNotNull(Pesanan::find($id)->dikirim_at);
        $this->assertDatabaseHas('pengiriman', [
            'pesanan_id' => $id,
            'status' => 'jalan',
            'diperbarui_oleh' => $admin->id,
        ]);
        $this->assertSame(1, Pengiriman::where('pesanan_id', $id)->count());
        $this->assertSame($stokSetelahCatat, (int) StokProduk::where('produk_id', $produk->id)->value('jumlah'));
        $this->assertSame(
            $mutasiSetelahCatat,
            MutasiStok::where('referensi_type', Pesanan::class)->where('referensi_id', $id)->count(),
        );
        $this->assertDatabaseHas('audit_logs', [
            'auditable_type' => Pesanan::class,
            'auditable_id' => $id,
            'aksi' => 'pesanan_dikirim',
            'status_dari' => 'diproses',
            'status_ke' => 'dikirim',
            'user_id' => $admin->id,
        ]);
        $auditJalan = AuditLog::where('aksi', 'pesanan_dikirim')->firstOrFail();
        $this->assertNotNull($auditJalan->created_at);
        $this->assertSame($id, $auditJalan->meta['pesanan_id']);
        $this->assertSame(
            Pengiriman::where('pesanan_id', $id)->value('id'),
            $auditJalan->meta['pengiriman_id'],
        );
        $this->assertSame('kurir', $auditJalan->meta['status_pengiriman_dari']);
        $this->assertSame('jalan', $auditJalan->meta['status_pengiriman_ke']);

        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertStatus(409);
        $this->assertSame(1, Pengiriman::where('pesanan_id', $id)->count());
        $this->assertSame($stokSetelahCatat, (int) StokProduk::where('produk_id', $produk->id)->value('jumlah'));
    }

    public function test_warehouse_tetap_membaca_pesanan_tetapi_tidak_bisa_mencatat_atau_menandai_jalan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();

        $warehouse = $this->sebagai(Peran::Warehouse);
        $warehouse->givePermissionTo('pesanan.proses');
        $warehouse->givePermissionTo('pengiriman.perbarui');
        $this->getJson('/api/pesanan')->assertOk()->assertJsonPath('data.items.0.id', $id);
        $this->getJson("/api/pesanan/{$id}")->assertOk()->assertJsonPath('data.id', $id);

        $stokSebelum = (int) StokProduk::where('produk_id', $produk->id)->value('jumlah');
        $mutasiSebelum = MutasiStok::count();
        $pengirimanSebelum = Pengiriman::count();
        $auditSebelum = AuditLog::count();
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())->assertForbidden();
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertForbidden();
        $this->postJson("/api/pesanan/{$id}/proses")->assertNotFound();
        $this->postJson("/api/pesanan/{$id}/kirim", $this->dataPengiriman())->assertNotFound();

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikonfirmasi']);
        $this->assertSame($stokSebelum, (int) StokProduk::where('produk_id', $produk->id)->value('jumlah'));
        $this->assertSame($mutasiSebelum, MutasiStok::count());
        $this->assertSame($pengirimanSebelum, Pengiriman::count());
        $this->assertSame($auditSebelum, AuditLog::count());
    }

    public function test_catat_pengiriman_memerlukan_data_pengemudi_terstruktur(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->sebagai(Peran::Admin);

        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", [
            'nama_pengemudi' => '',
            'telepon_pengemudi' => '',
            'nomor_kendaraan' => '',
        ])->assertUnprocessable()->assertJsonValidationErrors([
            'nama_pengemudi', 'telepon_pengemudi', 'nomor_kendaraan',
        ]);
    }

    public function test_catat_pengiriman_hanya_dapat_dilakukan_setelah_sales_menyetujui(): void
    {
        foreach (['menunggu_konfirmasi_sales', 'ditolak', 'dibatalkan'] as $status) {
            $retail = $this->buatRetail("retail-{$status}@toko.test", "Toko {$status}");
            $produk = $this->buatProduk(25);
            $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);

            if ($status === 'ditolak') {
                $this->sebagai(Peran::Sales);
                $this->postJson("/api/pesanan/{$id}/tolak", ['alasan' => 'Ditolak test'])->assertOk();
            } elseif ($status === 'dibatalkan') {
                Sanctum::actingAs($retail);
                $this->postJson("/api/pesanan/{$id}/batalkan", ['alasan' => 'Batal test'])->assertOk();
            }

            $this->sebagai(Peran::Admin);
            $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
                ->assertStatus(409)
                ->assertJsonPath('kode', 'STATUS_PESANAN_TIDAK_VALID');
            $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => $status]);
            $this->assertSame(0, Pengiriman::where('pesanan_id', $id)->count());
        }
    }

    public function test_catat_pengiriman_ditolak_jika_stok_tidak_cukup_tanpa_perubahan_data(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 5]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        StokProduk::where('produk_id', $produk->id)->update(['jumlah' => 2]);
        $this->sebagai(Peran::Admin);

        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
            ->assertUnprocessable()->assertJsonValidationErrors(['stok']);
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikonfirmasi']);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 2]);
        $this->assertDatabaseCount('pengiriman', 0);
        $this->assertDatabaseCount('mutasi_stok', 0);
    }

    public function test_gagal_mencatat_audit_membatalkan_seluruh_transaksi_pengiriman(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 3]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $admin = $this->sebagai(Peran::Admin);
        $jumlahAuditSebelum = AuditLog::count();

        DB::statement("CREATE TEMP TRIGGER gagal_sisip_audit BEFORE INSERT ON audit_logs BEGIN SELECT RAISE(ABORT, 'audit gagal'); END");
        $gagal = false;
        try {
            app(\App\Services\PesananService::class)->catatPengiriman(
                Pesanan::findOrFail($id),
                $this->dataPengiriman(),
                $admin,
            );
        } catch (\Throwable) {
            $gagal = true;
        } finally {
            DB::statement('DROP TRIGGER IF EXISTS gagal_sisip_audit');
        }

        $this->assertTrue($gagal, 'Kegagalan insert audit harus menggagalkan aksi pengiriman.');
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikonfirmasi']);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 10]);
        $this->assertDatabaseCount('pengiriman', 0);
        $this->assertDatabaseCount('mutasi_stok', 0);
        $this->assertSame($jumlahAuditSebelum, AuditLog::count());
    }

    public function test_tandai_jalan_memerlukan_pengiriman_dengan_status_kurir(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(10);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())->assertOk();

        Pengiriman::where('pesanan_id', $id)->update(['status' => 'jalan']);
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")
            ->assertStatus(409)
            ->assertJsonPath('kode', 'STATUS_PENGIRIMAN_TIDAK_VALID');
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diproses']);
    }

    // ------------------------------------------------------- Retail: terima

    public function test_retail_hanya_dapat_menerima_pesanan_setelah_jalan(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(100);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())
            ->assertForbidden();
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertForbidden();
        $this->postJson("/api/pesanan/{$id}/terima")->assertStatus(409);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $admin = $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())->assertOk();
        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")->assertStatus(409);
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diproses']);
        $this->assertDatabaseHas('pengiriman', ['pesanan_id' => $id, 'status' => 'kurir']);

        Sanctum::actingAs($admin);
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertOk();
        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")
            ->assertOk()
            ->assertJsonPath('data.status', 'diterima')
            ->assertJsonPath('data.pengiriman.status', 'diterima');

        $this->assertDatabaseHas('pesanan', [
            'id' => $id,
            'status' => 'diterima',
            'diterima_oleh' => $retail->id,
        ]);
        $this->assertDatabaseHas('pengiriman', [
            'pesanan_id' => $id,
            'status' => 'diterima',
            'diperbarui_oleh' => $retail->id,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'auditable_type' => Pesanan::class,
            'auditable_id' => $id,
            'aksi' => 'pesanan_diterima',
            'user_id' => $retail->id,
        ]);
        $auditTerima = AuditLog::where('aksi', 'pesanan_diterima')->firstOrFail();
        $this->assertNotNull($auditTerima->created_at);
        $this->assertSame($retail->id, $auditTerima->user_id);
        $this->assertSame($id, $auditTerima->meta['pesanan_id']);
        $this->assertSame(
            Pengiriman::where('pesanan_id', $id)->value('id'),
            $auditTerima->meta['pengiriman_id'],
        );
        $this->assertSame('jalan', $auditTerima->meta['status_pengiriman_dari']);
        $this->assertSame('diterima', $auditTerima->meta['status_pengiriman_ke']);
    }

    public function test_retail_lain_tidak_dapat_mengonfirmasi_pesanan(): void
    {
        $retail = $this->buatRetail();
        $retailLain = $this->buatRetail('retail-lain@toko.test', 'Toko B');
        $produk = $this->buatProduk(20);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())->assertOk();
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertOk();

        Sanctum::actingAs($retailLain);
        $this->postJson("/api/pesanan/{$id}/terima")->assertNotFound();
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikirim']);
    }

    public function test_endpoint_lama_tidak_dapat_membypass_alur_pengiriman_baru(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(20);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 1]]);
        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $this->sebagai(Peran::Admin);

        $this->postJson("/api/pesanan/{$id}/proses")->assertNotFound();
        $this->postJson("/api/pesanan/{$id}/kirim", $this->dataPengiriman())->assertNotFound();
        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'dikonfirmasi']);
        $this->assertDatabaseCount('pengiriman', 0);
        $this->assertDatabaseCount('mutasi_stok', 0);
    }

    public function test_alur_lengkap_dari_pesan_sampai_diterima(): void
    {
        $retail = $this->buatRetail();
        $produk = $this->buatProduk(20, ['harga' => 25000]);
        $id = $this->pesan($retail, [['produk_id' => $produk->id, 'qty' => 6]]);

        $this->sebagai(Peran::Sales);
        $this->postJson("/api/pesanan/{$id}/setujui")->assertOk();
        $admin = $this->sebagai(Peran::Admin);
        $this->postJson("/api/pesanan/{$id}/catat-pengiriman", $this->dataPengiriman())->assertOk();
        $this->postJson("/api/pesanan/{$id}/tandai-jalan")->assertOk();

        Sanctum::actingAs($retail);
        $this->postJson("/api/pesanan/{$id}/terima")->assertOk();

        $this->assertDatabaseHas('pesanan', ['id' => $id, 'status' => 'diterima']);
        $this->assertDatabaseHas('stok_produk', ['produk_id' => $produk->id, 'jumlah' => 14]);
        $this->assertDatabaseHas('pengiriman', ['pesanan_id' => $id, 'status' => 'diterima']);
        $this->assertSame(1, Pengiriman::where('pesanan_id', $id)->count());
        $detail = $this->getJson("/api/pesanan/{$id}")->assertOk();
        $this->assertEquals(150000, $detail->json('data.total'));
        $this->assertSame('Budi Santoso', $detail->json('data.pengiriman.nama_pengemudi'));
        $this->assertNotNull($detail->json('data.dikonfirmasi_at'));
        $this->assertNotNull($detail->json('data.diproses_at'));
        $this->assertNotNull($detail->json('data.dikirim_at'));
        $this->assertNotNull($detail->json('data.diterima_at'));
        $this->assertTrue($admin->can('pengiriman.perbarui'));
    }
}
