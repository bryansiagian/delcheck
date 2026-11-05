<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Enums\StatusPesanan;
use App\Models\ItemPesanan;
use App\Models\Pesanan;
use App\Models\Produk;
use App\Models\Retailer;
use App\Models\Retur;
use App\Models\User;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class ReturnApiTest extends TestCase
{
    use RefreshDatabase;

    private int $urut = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolePermissionSeeder::class);
        Storage::fake('local');
        config(['filesystems.default' => 'local']);
    }

    public function test_endpoint_return_mewajibkan_autentikasi_dan_permission_role(): void
    {
        $this->getJson('/api/retur')->assertUnauthorized();

        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item);
        Sanctum::actingAs($retail);
        $this->postJson('/api/retur/'.$retur->id.'/setujui')->assertForbidden();

        $admin = $this->buatUser(Peran::Admin);
        Sanctum::actingAs($admin);
        $this->postJson('/api/retur/'.$retur->id.'/ajukan')->assertForbidden();
    }

    public function test_retail_dapat_membuat_draft_multipart_melihat_data_sendiri_dan_mendapat_url_foto(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        Sanctum::actingAs($retail);

        $response = $this->post('/api/retur', [
            ...$this->dataDraft($pesanan, $item),
            'foto_kondisi' => [UploadedFile::fake()->image('kondisi.jpg')],
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.status_label', 'Draft')
            ->assertJsonPath('data.item.produk_id', $item->produk_id)
            ->assertJsonMissingPath('data.foto_kondisi.0.path');

        $id = $response->json('data.id');
        $response->assertJsonPath('data.foto_kondisi.0.jenis', 'kondisi_produk');
        $this->assertStringContainsString("/api/retur/{$id}/foto/", $response->json('data.foto_kondisi.0.url'));

        $this->getJson('/api/retur')->assertOk()->assertJsonPath('data.items.0.id', $id);
        $this->getJson("/api/retur/{$id}")->assertOk()->assertJsonPath('data.id', $id);
    }

    public function test_retail_tidak_dapat_membuat_return_dari_pesanan_milik_toko_lain(): void
    {
        $retail = $this->buatRetail();
        [, $pesananLain, $itemLain] = $this->buatPesananDiterima();
        Sanctum::actingAs($retail);

        $this->postJson('/api/retur', $this->dataDraft($pesananLain, $itemLain))
            ->assertNotFound()
            ->assertJsonPath('kode', 'PESANAN_TIDAK_DITEMUKAN');
    }

    public function test_retail_tidak_dapat_melihat_return_milik_toko_lain(): void
    {
        [$pemilik, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($pemilik, $pesanan, $item);
        $retailLain = $this->buatRetail();
        Sanctum::actingAs($retailLain);

        $this->getJson('/api/retur/'.$retur->id)->assertNotFound();
        $this->getJson('/api/retur')->assertOk()->assertJsonCount(0, 'data.items');
    }

    public function test_sales_dapat_membaca_pengajuan_dan_admin_hanya_melihat_status_logistik(): void
    {
        [$retailPending, $orderPending, $itemPending] = $this->buatPesananDiterima();
        $pending = $this->buatDraftViaApi($retailPending, $orderPending, $itemPending, true);
        $this->ajukanViaApi($retailPending, $pending);

        [$retailApproved, $orderApproved, $itemApproved] = $this->buatPesananDiterima();
        $approved = $this->buatDraftViaApi($retailApproved, $orderApproved, $itemApproved, true);
        $this->ajukanViaApi($retailApproved, $approved);
        $sales = $this->buatUser(Peran::Sales);
        Sanctum::actingAs($sales);
        $this->getJson('/api/retur')->assertOk()->assertJsonCount(2, 'data.items');

        $this->postJson('/api/retur/'.$approved->id.'/setujui')->assertOk();
        Sanctum::actingAs($sales);
        $this->getJson('/api/retur')->assertOk()->assertJsonCount(2, 'data.items')
            ->assertJsonFragment(['id' => $pending->id, 'status' => 'diajukan']);
        $this->getJson('/api/retur/'.$approved->id)->assertOk()
            ->assertJsonPath('data.status', 'disetujui');

        $admin = $this->buatUser(Peran::Admin);
        Sanctum::actingAs($admin);
        $this->getJson('/api/retur')->assertOk()->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.id', $approved->id);
        $this->getJson('/api/retur/'.$pending->id)->assertNotFound();
    }

    public function test_sales_dapat_melihat_riwayat_non_draft_dan_tetap_hanya_memiliki_akses_baca(): void
    {
        $statuses = ['diajukan', 'disetujui', 'ditolak', 'dijadwalkan', 'dijemput'];
        $returByStatus = [];

        foreach ($statuses as $status) {
            [$retail, $pesanan, $item] = $this->buatPesananDiterima();
            $retur = $this->buatDraftViaApi($retail, $pesanan, $item, true);
            $retur->update(['status' => $status]);
            $returByStatus[$status] = $retur->fresh();
        }

        [$retailDraft, $pesananDraft, $itemDraft] = $this->buatPesananDiterima();
        $draft = $this->buatDraftViaApi($retailDraft, $pesananDraft, $itemDraft);

        $sales = $this->buatUser(Peran::Sales);
        Sanctum::actingAs($sales);

        $this->getJson('/api/retur')->assertOk()
            ->assertJsonCount(count($statuses), 'data.items');
        $this->getJson('/api/retur?status=draft')->assertOk()
            ->assertJsonCount(0, 'data.items');
        $this->getJson('/api/retur/'.$draft->id)->assertNotFound();

        foreach ($statuses as $status) {
            $retur = $returByStatus[$status];
            $this->getJson('/api/retur?status='.$status)->assertOk()
                ->assertJsonCount(1, 'data.items')
                ->assertJsonPath('data.items.0.id', $retur->id)
                ->assertJsonPath('data.items.0.status', $status);
            $this->getJson('/api/retur/'.$retur->id)->assertOk()
                ->assertJsonPath('data.status', $status);
        }

        $returDiajukan = $returByStatus['diajukan']->load('retailer');
        $produk = $returDiajukan->item()->with('produk')->firstOrFail()->produk;
        foreach ([
            $returDiajukan->nomor,
            $returDiajukan->retailer->nama_toko,
            $produk->nama,
            $produk->kode,
        ] as $kataKunci) {
            $this->getJson('/api/retur?q='.urlencode($kataKunci))->assertOk()
                ->assertJsonCount(1, 'data.items')
                ->assertJsonPath('data.items.0.id', $returDiajukan->id);
        }

        $this->putJson('/api/retur/'.$draft->id, ['alasan' => 'Tidak boleh'])
            ->assertForbidden();
        $this->deleteJson('/api/retur/'.$draft->id)->assertForbidden();
        $this->putJson('/api/retur/'.$returByStatus['disetujui']->id.'/jadwal-penjemputan', [
            'jadwal_jemput' => '2026-11-10 09:30:00',
        ])->assertForbidden();
        $this->post('/api/retur/'.$returByStatus['dijadwalkan']->id.'/bukti-penjemputan', [], [
            'Accept' => 'application/json',
        ])->assertForbidden();

        $admin = $this->buatUser(Peran::Admin);
        $admin->givePermissionTo('retur.konfirmasi');
        Sanctum::actingAs($admin);
        $this->getJson('/api/retur')->assertOk()->assertJsonCount(3, 'data.items')
            ->assertJsonFragment(['status' => 'disetujui'])
            ->assertJsonFragment(['status' => 'dijadwalkan'])
            ->assertJsonFragment(['status' => 'dijemput'])
            ->assertJsonMissing(['status' => 'diajukan'])
            ->assertJsonMissing(['status' => 'ditolak']);
        $this->getJson('/api/retur/'.$returByStatus['diajukan']->id)->assertNotFound();
    }

    public function test_retail_dapat_mengubah_dan_menghapus_draft(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item);
        Sanctum::actingAs($retail);

        $this->putJson('/api/retur/'.$retur->id, [
            'qty' => 4,
            'alasan' => 'Deskripsi diperbarui',
        ])->assertOk()
            ->assertJsonPath('data.item.qty', 4)
            ->assertJsonPath('data.alasan', 'Deskripsi diperbarui');

        $this->deleteJson('/api/retur/'.$retur->id)->assertOk();
        $this->assertDatabaseMissing('retur', ['id' => $retur->id]);
    }

    public function test_update_json_tanpa_field_foto_mempertahankan_foto_kondisi_lama(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item, true);
        $fotoLama = $retur->fotoBukti()->where('jenis', 'kondisi_produk')->firstOrFail();
        $pathLama = $fotoLama->path;
        Sanctum::actingAs($retail);

        $this->putJson('/api/retur/'.$retur->id, ['alasan' => 'Alasan diperbarui'])
            ->assertOk()
            ->assertJsonPath('data.alasan', 'Alasan diperbarui')
            ->assertJsonPath('data.foto_kondisi.0.id', $fotoLama->id);

        $this->assertDatabaseHas('foto_bukti', ['id' => $fotoLama->id, 'path' => $pathLama]);
        Storage::disk('local')->assertExists($pathLama);
    }

    public function test_update_ditolak_jika_pesanan_asal_tidak_lagi_diterima(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item);
        $pesanan->update(['status' => StatusPesanan::Selesai]);
        Sanctum::actingAs($retail);

        $this->putJson('/api/retur/'.$retur->id, ['alasan' => 'Alasan baru'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['pesanan_id']);

        $this->assertDatabaseHas('retur', [
            'id' => $retur->id,
            'pesanan_id' => $pesanan->id,
            'status' => 'draft',
            'alasan' => 'Produk rusak saat diterima',
        ]);
    }

    public function test_post_multipart_dengan_method_spoof_put_mengganti_foto_kondisi(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item, true);
        $fotoLama = $retur->fotoBukti()->where('jenis', 'kondisi_produk')->firstOrFail();
        $pathLama = $fotoLama->path;
        Sanctum::actingAs($retail);

        $response = $this->post('/api/retur/'.$retur->id, [
            '_method' => 'PUT',
            'alasan' => 'Foto kondisi diperbarui',
            'foto_kondisi' => [UploadedFile::fake()->image('kondisi-baru.jpg')],
        ], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.alasan', 'Foto kondisi diperbarui')
            ->assertJsonCount(1, 'data.foto_kondisi');

        $fotoBaruId = $response->json('data.foto_kondisi.0.id');
        $fotoBaru = $retur->fotoBukti()->whereKey($fotoBaruId)->firstOrFail();

        $this->assertNotSame($fotoLama->id, $fotoBaruId);
        $this->assertDatabaseMissing('foto_bukti', ['id' => $fotoLama->id]);
        Storage::disk('local')->assertMissing($pathLama);
        Storage::disk('local')->assertExists($fotoBaru->path);
    }

    public function test_retail_tidak_dapat_memperbarui_return_milik_toko_lain(): void
    {
        [$pemilik, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($pemilik, $pesanan, $item, true);
        $retailLain = $this->buatRetail();
        Sanctum::actingAs($retailLain);

        $this->putJson('/api/retur/'.$retur->id, ['alasan' => 'Percobaan akses toko lain'])
            ->assertNotFound();

        $this->assertDatabaseHas('retur', [
            'id' => $retur->id,
            'alasan' => 'Produk rusak saat diterima',
            'status' => 'draft',
        ]);
    }

    public function test_retail_dapat_mengajukan_draft_tetapi_tidak_dapat_mengubahnya_lagi(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item, true);
        Sanctum::actingAs($retail);

        $this->postJson('/api/retur/'.$retur->id.'/ajukan')
            ->assertOk()
            ->assertJsonPath('data.status', 'diajukan');
        $this->putJson('/api/retur/'.$retur->id, ['alasan' => 'Ubah setelah diajukan'])
            ->assertStatus(409);
    }

    public function test_sales_dapat_menyetujui_atau_menolak_dengan_alasan_wajib(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $returSetuju = $this->buatDraftViaApi($retail, $pesanan, $item, true);
        $this->ajukanViaApi($retail, $returSetuju);
        $sales = $this->buatUser(Peran::Sales);
        Sanctum::actingAs($sales);
        $this->postJson('/api/retur/'.$returSetuju->id.'/setujui')
            ->assertOk()
            ->assertJsonPath('data.status', 'disetujui');

        [$retailLain, $pesananLain, $itemLain] = $this->buatPesananDiterima();
        $returTolak = $this->buatDraftViaApi($retailLain, $pesananLain, $itemLain, true);
        $this->ajukanViaApi($retailLain, $returTolak);
        Sanctum::actingAs($sales);
        $this->postJson('/api/retur/'.$returTolak->id.'/tolak', [])->assertUnprocessable()
            ->assertJsonValidationErrors(['alasan']);
        $this->postJson('/api/retur/'.$returTolak->id.'/tolak', ['alasan' => 'Bukti kurang jelas'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ditolak')
            ->assertJsonPath('data.alasan_ditolak', 'Bukti kurang jelas');
    }

    public function test_admin_dan_warehouse_dapat_mengatur_jadwal_dan_mengunggah_bukti(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($retail, $pesanan, $item, true);
        $this->ajukanViaApi($retail, $retur);
        $sales = $this->buatUser(Peran::Sales);
        Sanctum::actingAs($sales);
        $this->postJson('/api/retur/'.$retur->id.'/setujui')->assertOk();

        $admin = $this->buatUser(Peran::Admin);
        Sanctum::actingAs($admin);
        $this->putJson('/api/retur/'.$retur->id.'/jadwal-penjemputan', [
            'jadwal_jemput' => '2026-11-10 09:30:00',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'dijadwalkan')
            ->assertJsonPath('data.catatan_jemput', null);

        $this->post('/api/retur/'.$retur->id.'/bukti-penjemputan', [], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['foto_penjemputan']);
        $this->assertDatabaseHas('retur', ['id' => $retur->id, 'status' => 'dijadwalkan']);

        $warehouse = $this->buatUser(Peran::Warehouse);
        Sanctum::actingAs($warehouse);
        $this->putJson('/api/retur/'.$retur->id.'/jadwal-penjemputan', [
            'jadwal_jemput' => 'bukan tanggal',
        ])->assertUnprocessable()->assertJsonValidationErrors(['jadwal_jemput']);

        $this->putJson('/api/retur/'.$retur->id.'/jadwal-penjemputan', [
            'jadwal_jemput' => '2026-11-11 10:45:00',
            'catatan_jemput' => '  Jadwal diperbarui  ',
        ])->assertOk()->assertJsonPath('data.catatan_jemput', 'Jadwal diperbarui');

        $this->post('/api/retur/'.$retur->id.'/bukti-penjemputan', [
            'foto_penjemputan' => [UploadedFile::fake()->image('jemput.jpg')],
        ], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.status', 'dijemput')
            ->assertJsonPath('data.foto_penjemputan.0.jenis', 'bukti_penjemputan');

        $photoUrl = $this->getJson('/api/retur/'.$retur->id)
            ->assertOk()
            ->json('data.foto_penjemputan.0.url');
        $this->get(parse_url($photoUrl, PHP_URL_PATH), ['Accept' => 'image/*'])->assertOk();
    }

    public function test_foto_return_lain_tidak_dapat_diunduh_dengan_manipulasi_id(): void
    {
        [$pemilik, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = $this->buatDraftViaApi($pemilik, $pesanan, $item, true);
        $fotoId = $retur->fotoBukti()->where('jenis', 'kondisi_produk')->value('id');
        $retailLain = $this->buatRetail();
        Sanctum::actingAs($retailLain);

        $this->get('/api/retur/'.$retur->id.'/foto/'.$fotoId)->assertNotFound();
    }

    /** @return array{User, Pesanan, ItemPesanan} */
    private function buatPesananDiterima(): array
    {
        $retail = $this->buatRetail();
        $retailer = $retail->retailer;
        $this->urut++;
        $produk = Produk::create([
            'kode' => 'SKU-'.str_pad((string) $this->urut, 4, '0', STR_PAD_LEFT),
            'nama' => 'Produk '.$this->urut,
            'satuan' => 'pcs',
            'harga' => 1000,
            'stok_minimum' => 0,
            'is_active' => true,
        ]);
        $pesanan = Pesanan::create([
            'nomor' => 'PSN-'.str_pad((string) $this->urut, 8, '0', STR_PAD_LEFT),
            'retailer_id' => $retailer->id,
            'sumber' => 'retail',
            'dibuat_oleh' => $retail->id,
            'status' => StatusPesanan::Diterima,
            'total' => 2000,
        ]);
        $item = ItemPesanan::create([
            'pesanan_id' => $pesanan->id,
            'produk_id' => $produk->id,
            'nama_produk' => $produk->nama,
            'satuan' => $produk->satuan,
            'harga' => $produk->harga,
            'qty' => 2,
            'subtotal' => 2000,
        ]);

        return [$retail, $pesanan, $item];
    }

    private function buatRetail(): User
    {
        $user = $this->buatUser(Peran::Retail);
        Retailer::create([
            'user_id' => $user->id,
            'kode' => 'RTL-'.str_pad((string) $user->id, 6, '0', STR_PAD_LEFT),
            'nama_toko' => 'Toko '.$user->id,
            'alamat' => 'Alamat test',
            'status_verifikasi' => 'disetujui',
        ]);

        return $user->fresh('retailer');
    }

    private function buatUser(Peran $peran): User
    {
        $role = Role::findOrCreate($peran->value, 'web');
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole($role);

        return $user;
    }

    private function buatDraftViaApi(User $retail, Pesanan $pesanan, ItemPesanan $item, bool $denganFoto = false): Retur
    {
        Sanctum::actingAs($retail);
        $data = $this->dataDraft($pesanan, $item);
        if ($denganFoto) {
            $data['foto_kondisi'] = [UploadedFile::fake()->image('kondisi.jpg')];
        }

        $response = $this->post('/api/retur', $data, ['Accept' => 'application/json'])->assertCreated();

        return Retur::findOrFail($response->json('data.id'));
    }

    private function ajukanViaApi(User $retail, Retur $retur): void
    {
        Sanctum::actingAs($retail);
        $this->postJson('/api/retur/'.$retur->id.'/ajukan')->assertOk();
    }

    /** @return array{pesanan_id: int, item_pesanan_id: int, qty: int, alasan: string, jenis_penyelesaian: string} */
    private function dataDraft(Pesanan $pesanan, ItemPesanan $item): array
    {
        return [
            'pesanan_id' => $pesanan->id,
            'item_pesanan_id' => $item->id,
            'qty' => 1,
            'alasan' => 'Produk rusak saat diterima',
            'jenis_penyelesaian' => 'refund',
        ];
    }
}
