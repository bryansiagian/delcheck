<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Ringkas untuk daftar pengguna (tanpa daftar izin). @mixin \App\Models\User */
class PenggunaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'is_active' => (bool) $this->is_active,
            'roles' => $this->getRoleNames()->values(),
            'last_login_at' => $this->last_login_at?->toIso8601String(),
            'retailer' => $this->whenLoaded('retailer', fn () => $this->retailer ? [
                'id' => $this->retailer->id,
                'nama_toko' => $this->retailer->nama_toko,
                'status_verifikasi' => $this->retailer->status_verifikasi?->value,
            ] : null),
        ];
    }
}
