<?php

namespace App\Services;

use App\Enums\StatusPesanan;
use App\Enums\StatusVerifikasi;
use App\Exceptions\ApiException;
use App\Models\AuditLog;
use App\Models\Pengiriman;
use App\Models\Pesanan;
use App\Models\Produk;
use App\Models\StokProduk;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Alur pesanan:
 *  Retail membuat -> Sales setujui/tolak -> Warehouse/Admin serahkan ke kurir
 *  dan tandai dalam perjalanan -> Retail konfirmasi diterima.
 * Stok berkurang saat pesanan ditandai "dikirim" (BR-07).
 */
class PesananService
{
    /** Relasi yang dimuat untuk respons detail. */
    public const MUAT = ['retailer:id,kode,nama_toko', 'sales:id,name', 'items', 'pengiriman'];

    public function __construct(private StokService $stok)
    {
    }

    // ------------------------------------------------------------ Retail

    /**
     * @param  array{items: array<int, array{produk_id: int, qty: int}>, catatan?: ?string}  $data
     */
    public function buat(User $user, array $data): Pesanan
    {
        $retailer = $user->retailer;

        if (! $retailer || $retailer->status_verifikasi !== StatusVerifikasi::Disetujui) {
            throw new ApiException(
                'Hanya akun toko yang sudah terverifikasi yang dapat membuat pesanan.',
                403,
                'TOKO_TIDAK_DITEMUKAN',
            );
        }

        $items = array_values($data['items']);
        $ids = array_map(fn ($item) => (int) $item['produk_id'], $items);

        $produk = Produk::query()->whereIn('id', $ids)->where('is_active', true)->get()->keyBy('id');
        $stok = StokProduk::whereIn('produk_id', $ids)->pluck('jumlah', 'produk_id');

        $galat = [];
        $baris = [];
        $total = 0.0;

        foreach ($items as $i => $item) {
            $p = $produk->get((int) $item['produk_id']);
            $qty = (int) $item['qty'];

            if (! $p) {
                $galat["items.{$i}.produk_id"] = 'Produk tidak tersedia.';

                continue;
            }

            $tersedia = (int) $stok->get($p->id, 0);
            if ($qty > $tersedia) {
                $galat["items.{$i}.qty"] = "Stok {$p->nama} hanya tersedia {$tersedia} {$p->satuan}.";

                continue;
            }

            // Harga disalin (snapshot) agar perubahan harga tidak mengubah pesanan lama.
            $harga = round((float) $p->harga, 2);
            $subtotal = round($harga * $qty, 2);
            $total += $subtotal;

            $baris[] = [
                'produk_id' => $p->id,
                'nama_produk' => $p->nama,
                'satuan' => $p->satuan,
                'harga' => $harga,
                'qty' => $qty,
                'subtotal' => $subtotal,
            ];
        }

        if ($galat !== []) {
            throw ValidationException::withMessages($galat);
        }

        return DB::transaction(function () use ($user, $retailer, $data, $baris, $total) {
            $pesanan = Pesanan::create([
                'nomor' => 'TMP-'.Str::uuid(),
                'retailer_id' => $retailer->id,
                'sumber' => 'retail',
                'dibuat_oleh' => $user->id,
                'status' => StatusPesanan::MenungguKonfirmasiSales,
                'total' => round($total, 2),
                'catatan' => $data['catatan'] ?? null,
            ]);

            $pesanan->update([
                'nomor' => sprintf('PSN-%s-%05d', now()->format('Ymd'), $pesanan->id),
            ]);

            $pesanan->items()->createMany($baris);

            return $pesanan->load(self::MUAT);
        });
    }

    /** Retail membatalkan pesanan miliknya selama belum diproses Sales. */
    public function batalkan(Pesanan $pesanan, string $alasan, User $user): Pesanan
    {
        $this->pastikanMilik($pesanan, $user);

        return DB::transaction(function () use ($pesanan, $alasan, $user) {
            $p = $this->kunci($pesanan, [StatusPesanan::MenungguKonfirmasiSales]);

            $p->update([
                'status' => StatusPesanan::Dibatalkan,
                'dibatalkan_oleh' => $user->id,
                'dibatalkan_at' => now(),
                'alasan_batal' => $alasan,
            ]);

            AuditLog::catat(
                $p,
                'pesanan_dibatalkan',
                StatusPesanan::MenungguKonfirmasiSales->value,
                StatusPesanan::Dibatalkan->value,
                $alasan,
                [],
                $user->id,
            );

            return $p->load(self::MUAT);
        });
    }

    /** Retail mengonfirmasi barang sudah sampai. */
    public function terima(Pesanan $pesanan, User $user): Pesanan
    {
        $this->pastikanMilik($pesanan, $user);

        return DB::transaction(function () use ($pesanan, $user) {
            $p = $this->kunci($pesanan, [StatusPesanan::Dikirim]);
            $sekarang = now();

            $p->update([
                'status' => StatusPesanan::Diterima,
                'diterima_oleh' => $user->id,
                'diterima_at' => $sekarang,
            ]);

            $p->pengiriman()->where('status', 'dikirim')->update([
                'status' => 'diterima',
                'diterima_at' => $sekarang,
            ]);

            AuditLog::catat(
                $p,
                'pesanan_diterima',
                StatusPesanan::Dikirim->value,
                StatusPesanan::Diterima->value,
                null,
                [],
                $user->id,
            );

            return $p->load(self::MUAT);
        });
    }

    // ------------------------------------------------------------- Sales

    public function setujui(Pesanan $pesanan, User $sales): Pesanan
    {
        return DB::transaction(function () use ($pesanan, $sales) {
            $p = $this->kunci($pesanan, [StatusPesanan::MenungguKonfirmasiSales]);

            $p->update([
                'status' => StatusPesanan::Dikonfirmasi,
                'sales_id' => $sales->id,
                'dikonfirmasi_oleh' => $sales->id,
                'dikonfirmasi_at' => now(),
                'alasan_ditolak' => null,
            ]);

            AuditLog::catat(
                $p,
                'pesanan_dikonfirmasi',
                StatusPesanan::MenungguKonfirmasiSales->value,
                StatusPesanan::Dikonfirmasi->value,
                null,
                [],
                $sales->id,
            );

            return $p->load(self::MUAT);
        });
    }

    /** Alasan wajib (BR-06). dikonfirmasi_oleh/at dipakai sebagai "diputuskan oleh/pada". */
    public function tolak(Pesanan $pesanan, string $alasan, User $sales): Pesanan
    {
        return DB::transaction(function () use ($pesanan, $alasan, $sales) {
            $p = $this->kunci($pesanan, [StatusPesanan::MenungguKonfirmasiSales]);

            $p->update([
                'status' => StatusPesanan::Ditolak,
                'sales_id' => $sales->id,
                'dikonfirmasi_oleh' => $sales->id,
                'dikonfirmasi_at' => now(),
                'alasan_ditolak' => $alasan,
            ]);

            AuditLog::catat(
                $p,
                'pesanan_ditolak',
                StatusPesanan::MenungguKonfirmasiSales->value,
                StatusPesanan::Ditolak->value,
                $alasan,
                [],
                $sales->id,
            );

            return $p->load(self::MUAT);
        });
    }

    // --------------------------------------------------- Warehouse / Admin

    /** Barang sudah diserahkan ke kurir. */
    public function proses(Pesanan $pesanan, User $user): Pesanan
    {
        return DB::transaction(function () use ($pesanan, $user) {
            $p = $this->kunci($pesanan, [StatusPesanan::Dikonfirmasi]);

            $p->update([
                'status' => StatusPesanan::Diproses,
                'diproses_oleh' => $user->id,
                'diproses_at' => now(),
            ]);

            AuditLog::catat(
                $p,
                'pesanan_diproses',
                StatusPesanan::Dikonfirmasi->value,
                StatusPesanan::Diproses->value,
                null,
                [],
                $user->id,
            );

            return $p->load(self::MUAT);
        });
    }

    /**
     * Barang dalam perjalanan: mencatat pengiriman dan mengurangi stok.
     * Boleh langsung dari "dikonfirmasi" (melewati "diserahkan ke kurir").
     *
     * @param  array{tanggal_kirim: string, estimasi_tiba?: ?string, nomor_surat_jalan?: ?string, catatan?: ?string}  $data
     */
    public function kirim(Pesanan $pesanan, array $data, User $user): Pesanan
    {
        return DB::transaction(function () use ($pesanan, $data, $user) {
            $p = $this->kunci($pesanan, [StatusPesanan::Dikonfirmasi, StatusPesanan::Diproses]);
            $dari = $p->status;

            $items = $p->items()->orderBy('produk_id')->get();

            // Kunci baris stok berurutan (hindari deadlock), lalu cek semua item sekaligus.
            $kurang = [];
            foreach ($items as $item) {
                StokProduk::firstOrCreate(['produk_id' => $item->produk_id], ['jumlah' => 0]);
                $tersedia = (int) StokProduk::where('produk_id', $item->produk_id)->lockForUpdate()->value('jumlah');

                if ($tersedia < $item->qty) {
                    $kurang[] = "{$item->nama_produk} (butuh {$item->qty}, tersedia {$tersedia})";
                }
            }

            if ($kurang !== []) {
                throw ValidationException::withMessages([
                    'stok' => 'Stok tidak mencukupi: '.implode('; ', $kurang).'.',
                ]);
            }

            foreach ($items as $item) {
                $this->stok->ubah(
                    $item->produk_id,
                    'keluar',
                    (int) $item->qty,
                    "Pengiriman pesanan {$p->nomor}",
                    $user,
                    $p,
                    'stok',
                );
            }

            $sekarang = now();

            $p->update([
                'status' => StatusPesanan::Dikirim,
                'dikirim_at' => $sekarang,
                'diproses_oleh' => $p->diproses_oleh ?? $user->id,
                'diproses_at' => $p->diproses_at ?? $sekarang,
            ]);

            Pengiriman::create([
                'pesanan_id' => $p->id,
                'nomor_surat_jalan' => $data['nomor_surat_jalan'] ?? null,
                'status' => 'dikirim',
                'tanggal_kirim' => $data['tanggal_kirim'],
                'estimasi_tiba' => $data['estimasi_tiba'] ?? null,
                'catatan' => $data['catatan'] ?? null,
                'diperbarui_oleh' => $user->id,
            ]);

            AuditLog::catat(
                $p,
                'pesanan_dikirim',
                $dari->value,
                StatusPesanan::Dikirim->value,
                null,
                [],
                $user->id,
            );

            return $p->load(self::MUAT);
        });
    }

    // ---------------------------------------------------------- pembantu

    /** Kunci baris agar dua orang tidak memproses pesanan yang sama bersamaan. */
    private function kunci(Pesanan $pesanan, array $diizinkan): Pesanan
    {
        $terkini = Pesanan::query()->lockForUpdate()->findOrFail($pesanan->id);

        if (! in_array($terkini->status, $diizinkan, true)) {
            throw new ApiException(
                "Pesanan berstatus \"{$terkini->status->label()}\", tindakan ini tidak dapat dilakukan.",
                409,
                'STATUS_PESANAN_TIDAK_VALID',
            );
        }

        return $terkini;
    }

    /** Retail hanya boleh mengubah pesanan tokonya sendiri. */
    private function pastikanMilik(Pesanan $pesanan, User $user): void
    {
        if (! $user->retailer || $user->retailer->id !== $pesanan->retailer_id) {
            throw new ApiException('Pesanan tidak ditemukan.', 404, 'PESANAN_TIDAK_DITEMUKAN');
        }
    }
}
