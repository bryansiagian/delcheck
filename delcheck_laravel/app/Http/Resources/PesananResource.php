<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Pesanan */
class PesananResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nomor' => $this->nomor,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'sumber' => $this->sumber,
            'total' => (float) $this->total,
            'catatan' => $this->catatan,
            'jumlah_item' => $this->items_count
                ?? ($this->relationLoaded('items') ? $this->items->count() : null),

            'retailer' => $this->whenLoaded('retailer', fn () => $this->retailer ? [
                'id' => $this->retailer->id,
                'kode' => $this->retailer->kode,
                'nama_toko' => $this->retailer->nama_toko,
            ] : null),
            'sales' => $this->whenLoaded('sales', fn () => $this->sales?->name),

            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => [
                'id' => $item->id,
                'produk_id' => $item->produk_id,
                'nama_produk' => $item->nama_produk,
                'satuan' => $item->satuan,
                'harga' => (float) $item->harga,
                'qty' => $item->qty,
                'subtotal' => (float) $item->subtotal,
            ])->values()),

            'pengiriman' => $this->whenLoaded('pengiriman', function () {
                $kirim = $this->pengiriman->sortByDesc('id')->first();

                return $kirim ? [
                    'id' => $kirim->id,
                    'nomor_surat_jalan' => $kirim->nomor_surat_jalan,
                    'status' => $kirim->status,
                    'tanggal_kirim' => $kirim->tanggal_kirim?->toDateString(),
                    'estimasi_tiba' => $kirim->estimasi_tiba?->toDateString(),
                    'diterima_at' => $kirim->diterima_at?->toIso8601String(),
                    'catatan' => $kirim->catatan,
                ] : null;
            }),

            'alasan_ditolak' => $this->alasan_ditolak,
            'alasan_batal' => $this->alasan_batal,

            'created_at' => $this->created_at?->toIso8601String(),
            'dikonfirmasi_at' => $this->dikonfirmasi_at?->toIso8601String(),
            'diproses_at' => $this->diproses_at?->toIso8601String(),
            'dikirim_at' => $this->dikirim_at?->toIso8601String(),
            'diterima_at' => $this->diterima_at?->toIso8601String(),
            'dibatalkan_at' => $this->dibatalkan_at?->toIso8601String(),
        ];
    }
}
