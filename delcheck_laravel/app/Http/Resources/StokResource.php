<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Produk beserta jumlah stoknya. Resource ini berasal dari Produk::denganStok(),
 * sehingga `id` adalah id produk.
 *
 * @mixin \App\Models\Produk
 */
class StokResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $jumlah = (int) ($this->stok_jumlah ?? 0);

        return [
            'id' => $this->id,
            'kode' => $this->kode,
            'nama' => $this->nama,
            'satuan' => $this->satuan,
            'is_active' => $this->is_active,
            'stok_minimum' => $this->stok_minimum,
            'jumlah' => $jumlah,
            'habis' => $jumlah === 0,
            'menipis' => $jumlah <= $this->stok_minimum,
        ];
    }
}
