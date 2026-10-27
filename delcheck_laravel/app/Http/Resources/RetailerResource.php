<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Retailer */
class RetailerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'kode' => $this->kode,
            'nama_toko' => $this->nama_toko,
            'nama_pemilik' => $this->nama_pemilik,
            'alamat' => $this->alamat,
            'telepon' => $this->telepon,
            'email' => $this->email,
            'status_verifikasi' => $this->status_verifikasi?->value,
            'alasan_ditolak' => $this->alasan_ditolak,
            'diverifikasi_at' => $this->diverifikasi_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),

            'wilayah' => $this->whenLoaded('wilayah', fn () => $this->wilayah ? [
                'id' => $this->wilayah->id,
                'nama' => $this->wilayah->nama,
            ] : null),

            'user' => $this->whenLoaded('user', fn () => $this->user ? [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'email' => $this->user->email,
                'phone' => $this->user->phone,
                'is_active' => (bool) $this->user->is_active,
            ] : null),

            'diverifikasi_oleh' => $this->whenLoaded('diverifikasiOleh', fn () => $this->diverifikasiOleh ? [
                'id' => $this->diverifikasiOleh->id,
                'name' => $this->diverifikasiOleh->name,
            ] : null),

            'sales' => $this->whenLoaded('sales', fn () => $this->sales->map(fn ($sales) => [
                'id' => $sales->id,
                'name' => $sales->name,
            ])->values()),
        ];
    }
}
