<?php

namespace App\Services;

use App\Models\MutasiStok;
use App\Models\StokProduk;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Validation\ValidationException;

/**
 * Satu-satunya tempat stok berubah: mengunci baris stok, menjaga stok tidak
 * negatif, dan mencatat mutasi. HARUS dipanggil di dalam DB::transaction.
 */
class StokService
{
    /**
     * @param  string  $tipe  'masuk' atau 'keluar'
     * @param  string  $fieldError  kunci error validasi jika stok tidak cukup
     */
    public function ubah(
        int $produkId,
        string $tipe,
        int $jumlah,
        ?string $alasan,
        User $oleh,
        ?Model $referensi = null,
        string $fieldError = 'jumlah',
    ): StokProduk {
        StokProduk::firstOrCreate(['produk_id' => $produkId], ['jumlah' => 0]);

        // Kunci baris agar dua perubahan bersamaan tidak saling menimpa.
        $stok = StokProduk::where('produk_id', $produkId)->lockForUpdate()->firstOrFail();

        $sebelum = (int) $stok->jumlah;
        $sesudah = $tipe === 'keluar' ? $sebelum - $jumlah : $sebelum + $jumlah;

        if ($sesudah < 0) {
            throw ValidationException::withMessages([
                $fieldError => "Stok tidak mencukupi. Stok saat ini: {$sebelum}.",
            ]);
        }

        $stok->update(['jumlah' => $sesudah]);

        MutasiStok::create([
            'produk_id' => $produkId,
            'tipe' => $tipe,
            'jumlah' => $tipe === 'keluar' ? -$jumlah : $jumlah,
            'stok_sebelum' => $sebelum,
            'stok_sesudah' => $sesudah,
            'alasan' => $alasan,
            'referensi_type' => $referensi?->getMorphClass(),
            'referensi_id' => $referensi?->getKey(),
            'dibuat_oleh' => $oleh->id,
        ]);

        return $stok->refresh();
    }
}
