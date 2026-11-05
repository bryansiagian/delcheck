<?php

namespace Tests\Feature;

use App\Enums\Peran;
use App\Enums\StatusPesanan;
use App\Enums\StatusRetur;
use App\Exceptions\ApiException;
use App\Models\FotoBukti;
use App\Models\ItemPesanan;
use App\Models\Pesanan;
use App\Models\Produk;
use App\Models\Retailer;
use App\Models\User;
use App\Services\ReturService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class ReturnServiceTest extends TestCase
{
    use RefreshDatabase;

    private int $urut = 0;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        config(['filesystems.default' => 'local']);
    }

    public function test_retail_dapat_membuat_draft_satu_produk_tanpa_batas_qty_dan_mengajukannya_dengan_foto(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $service = app(ReturService::class);

        $retur = $service->buatDraft($retail, [
            'pesanan_id' => $pesanan->id,
            'item_pesanan_id' => $item->id,
            'qty' => 99,
            'alasan' => 'Produk rusak',
            'jenis_penyelesaian' => 'refund',
        ], [UploadedFile::fake()->image('kondisi.jpg')]);

        $this->assertSame(StatusRetur::Draft, $retur->status);
        $this->assertSame(99, $retur->item->qty);
        $this->assertSame('kondisi_produk', $retur->fotoBukti->first()->jenis);

        $retur = $service->ajukan($retur, $retail);
        $this->assertSame(StatusRetur::Diajukan, $retur->status);
        $this->assertDatabaseHas('retur', ['id' => $retur->id, 'status' => 'diajukan']);
    }

    public function test_foto_kondisi_wajib_sebelum_pengajuan(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, [
            'pesanan_id' => $pesanan->id,
            'item_pesanan_id' => $item->id,
            'qty' => 1,
            'alasan' => 'Produk rusak',
            'jenis_penyelesaian' => 'replacement',
        ]);

        try {
            $service->ajukan($retur, $retail);
            $this->fail('Pengajuan tanpa foto kondisi seharusnya ditolak.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('foto_kondisi', $exception->errors());
        }
    }

    public function test_draft_dapat_mengganti_pesanan_dan_produk_tujuan(): void
    {
        [$retail, $pesananAsal, $itemAsal] = $this->buatPesananDiterima();
        $tujuan = $this->buatPesanan($retail, StatusPesanan::Diterima);
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, $this->dataDraft($pesananAsal, $itemAsal));

        $retur = $service->perbaruiDraft($retur, $retail, [
            'pesanan_id' => $tujuan['pesanan']->id,
            'item_pesanan_id' => $tujuan['item']->id,
            'qty' => 3,
        ]);

        $this->assertSame($tujuan['pesanan']->id, $retur->pesanan_id);
        $this->assertSame($tujuan['item']->id, $retur->item->item_pesanan_id);
        $this->assertSame($tujuan['item']->produk_id, $retur->item->produk_id);
        $this->assertSame(3, $retur->item->qty);
    }

    public function test_draft_tidak_dapat_diedit_jika_pesanan_asal_tidak_lagi_diterima(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item));
        $pesanan->update(['status' => StatusPesanan::Selesai]);

        try {
            $service->perbaruiDraft($retur, $retail, ['alasan' => 'Alasan baru']);
            $this->fail('Draft dengan pesanan yang tidak lagi diterima seharusnya ditolak.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('pesanan_id', $exception->errors());
        }

        $this->assertDatabaseHas('retur', [
            'id' => $retur->id,
            'pesanan_id' => $pesanan->id,
            'status' => 'draft',
            'alasan' => 'Produk rusak saat diterima',
        ]);
    }

    public function test_file_baru_dibersihkan_jika_transaksi_database_gagal(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        FotoBukti::creating(function (): never {
            throw new \RuntimeException('Simulasi kegagalan penyimpanan foto.');
        });

        try {
            app(ReturService::class)->buatDraft(
                $retail,
                $this->dataDraft($pesanan, $item),
                [UploadedFile::fake()->image('kondisi.jpg')],
            );
            $this->fail('Kegagalan penyimpanan foto seharusnya membatalkan operasi.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('Simulasi kegagalan penyimpanan foto.', $exception->getMessage());
        }

        $this->assertDatabaseCount('retur', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_retail_dapat_menghapus_draft_saat_pesanan_masih_diterima(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = app(ReturService::class)->buatDraft($retail, $this->dataDraft($pesanan, $item));

        app(ReturService::class)->hapusDraft($retur, $retail);

        $this->assertDatabaseMissing('retur', ['id' => $retur->id]);
    }

    public function test_retail_dapat_menghapus_draft_setelah_status_pesanan_berubah(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $retur = app(ReturService::class)->buatDraft($retail, $this->dataDraft($pesanan, $item));
        $pesanan->update(['status' => StatusPesanan::Selesai]);

        app(ReturService::class)->hapusDraft($retur, $retail);

        $this->assertDatabaseMissing('retur', ['id' => $retur->id]);
    }

    public function test_retail_tidak_dapat_menghapus_return_milik_toko_lain(): void
    {
        [$pemilik, $pesanan, $item] = $this->buatPesananDiterima();
        [$retailLain] = $this->buatPesananDiterima();
        $retur = app(ReturService::class)->buatDraft($pemilik, $this->dataDraft($pesanan, $item));

        try {
            app(ReturService::class)->hapusDraft($retur, $retailLain);
            $this->fail('Retail lain tidak boleh menghapus Return ini.');
        } catch (ApiException) {
            // Penolakan akses sudah terjadi; data harus tetap ada.
        }

        $this->assertDatabaseHas('retur', ['id' => $retur->id, 'status' => 'draft']);
    }

    public function test_retail_tidak_dapat_menghapus_return_yang_bukan_draft(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi.jpg')]);
        $retur = $service->ajukan($retur, $retail);

        try {
            $service->hapusDraft($retur, $retail);
            $this->fail('Return yang sudah diajukan tidak boleh dihapus.');
        } catch (ApiException $exception) {
            $this->assertStringContainsString('tindakan ini tidak dapat dilakukan', $exception->getMessage());
        }

        $this->assertDatabaseHas('retur', ['id' => $retur->id, 'status' => 'diajukan']);
    }

    public function test_penolakan_terminal_mengizinkan_pengajuan_baru_untuk_produk_yang_sama(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $sales = $this->buatUser(Peran::Sales);
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi.jpg')]);
        $retur = $service->ajukan($retur, $retail);
        $retur = $service->tolak($retur, 'Bukti tidak cukup', $sales);

        $this->assertSame(StatusRetur::Ditolak, $retur->status);
        $baru = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi-baru.jpg')]);
        $this->assertSame(StatusRetur::Draft, $baru->status);

        $this->expectException(ApiException::class);
        $service->perbaruiDraft($retur, $retail, ['alasan' => 'Tidak boleh diedit']);
    }

    public function test_alur_sales_sampai_penjemputan_membutuhkan_bukti_foto(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $sales = $this->buatUser(Peran::Sales);
        $admin = $this->buatUser(Peran::Admin);
        $service = app(ReturService::class);

        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi.jpg')]);
        $retur = $service->ajukan($retur, $retail);
        $retur = $service->setujui($retur, $sales);
        $retur = $service->jadwalkanPenjemputan($retur, '2026-11-10 09:30:00', 'Ambil di toko', $admin);
        $this->assertSame(StatusRetur::Dijadwalkan, $retur->status);

        $retur = $service->unggahBuktiPenjemputan($retur, [UploadedFile::fake()->image('jemput.jpg')], $admin);
        $this->assertSame(StatusRetur::Dijemput, $retur->status);
        $this->assertNotNull($retur->dijemput_at);
        $this->assertSame(1, $retur->fotoBukti->where('jenis', 'bukti_penjemputan')->count());
        $this->assertDatabaseHas('retur', ['id' => $retur->id, 'status' => 'dijemput']);
    }

    public function test_jadwal_penjemputan_menerima_catatan_opsional_dan_menolak_waktu_tidak_valid(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $sales = $this->buatUser(Peran::Sales);
        $admin = $this->buatUser(Peran::Admin);
        $service = app(ReturService::class);

        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi.jpg')]);
        $retur = $service->ajukan($retur, $retail);
        $retur = $service->setujui($retur, $sales);

        $retur = $service->jadwalkanPenjemputan($retur, '2026-11-10 09:30:00', null, $admin);
        $this->assertSame(StatusRetur::Dijadwalkan, $retur->status);
        $this->assertNull($retur->catatan_jemput);

        $retur = $service->jadwalkanPenjemputan($retur, '2026-11-11 10:45:00', '  Ambil di toko  ', $admin);
        $this->assertSame('Ambil di toko', $retur->catatan_jemput);

        try {
            $service->jadwalkanPenjemputan($retur, 'bukan tanggal', null, $admin);
            $this->fail('Jadwal dengan tanggal/waktu tidak valid seharusnya ditolak.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('jadwal_jemput', $exception->errors());
        }
    }

    public function test_hanya_pesanan_diterima_milik_retail_dan_item_pesanan_yang_benar_dapat_digunakan(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        [$retailLain, $pesananLain, $itemLain] = $this->buatPesananDiterima();
        $service = app(ReturService::class);

        try {
            $service->buatDraft($retail, $this->dataDraft($pesananLain, $itemLain));
            $this->fail('Pesanan milik Retail lain seharusnya ditolak.');
        } catch (ApiException $exception) {
            $this->assertSame('Pesanan tidak ditemukan.', $exception->getMessage());
        }

        $pesananBelumDiterima = $this->buatPesanan($retail, StatusPesanan::Dikirim);
        try {
            $service->buatDraft($retail, $this->dataDraft($pesananBelumDiterima['pesanan'], $pesananBelumDiterima['item']));
            $this->fail('Pesanan yang belum diterima seharusnya ditolak.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('pesanan_id', $exception->errors());
        }

        $data = $this->dataDraft($pesanan, $item);
        $data['item_pesanan_id'] = $itemLain->id;
        $this->expectException(ValidationException::class);
        $service->buatDraft($retail, $data);
    }

    public function test_hanya_sales_dapat_memutuskan_dan_hanya_admin_atau_warehouse_dapat_menjadwalkan(): void
    {
        [$retail, $pesanan, $item] = $this->buatPesananDiterima();
        $operator = $this->buatUser(Peran::Retail);
        $service = app(ReturService::class);
        $retur = $service->buatDraft($retail, $this->dataDraft($pesanan, $item), [UploadedFile::fake()->image('kondisi.jpg')]);
        $retur = $service->ajukan($retur, $retail);

        try {
            $service->setujui($retur, $operator);
            $this->fail('Retail tidak boleh menyetujui Return.');
        } catch (ApiException $exception) {
            $this->assertSame('Peran akun tidak diizinkan melakukan tindakan Return ini.', $exception->getMessage());
        }

        $this->expectException(ApiException::class);
        $service->jadwalkanPenjemputan($retur, '2026-11-10 09:30:00', 'Ambil di toko', $operator);
    }

    /** @return array{User, Pesanan, ItemPesanan} */
    private function buatPesananDiterima(): array
    {
        $retail = $this->buatUser(Peran::Retail);
        $retailer = Retailer::create([
            'user_id' => $retail->id,
            'kode' => 'RTL-'.str_pad((string) $retail->id, 6, '0', STR_PAD_LEFT),
            'nama_toko' => 'Toko '.$retail->id,
            'alamat' => 'Alamat test',
            'status_verifikasi' => 'disetujui',
        ]);
        $data = $this->buatPesanan($retail, StatusPesanan::Diterima, $retailer);

        return [$retail, $data['pesanan'], $data['item']];
    }

    /** @return array{pesanan: Pesanan, item: ItemPesanan} */
    private function buatPesanan(User $retail, StatusPesanan $status, ?Retailer $retailer = null): array
    {
        if (! $retailer) {
            $retailer = Retailer::where('user_id', $retail->id)->firstOrFail();
        }

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
            'status' => $status,
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

        return ['pesanan' => $pesanan, 'item' => $item];
    }

    private function buatUser(Peran $peran): User
    {
        $role = Role::findOrCreate($peran->value, 'web');
        $user = User::factory()->create(['is_active' => true]);
        $user->assignRole($role);

        return $user;
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
