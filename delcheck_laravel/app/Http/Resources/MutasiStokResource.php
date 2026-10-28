<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\MutasiStok */
class MutasiStokResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'tipe' => $this->tipe,
            'jumlah' => $this->jumlah,
            'stok_sebelum' => $this->stok_sebelum,
            'stok_sesudah' => $this->stok_sesudah,
            'alasan' => $this->alasan,
            'dibuat_oleh' => $this->pembuat?->name,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
