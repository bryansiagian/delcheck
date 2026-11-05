<?php

namespace App\Http\Resources;

use App\Models\FotoBukti;
use App\Models\Retur;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

/** @mixin Retur */
class ReturResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nomor' => $this->nomor,
            'pesanan' => $this->whenLoaded('pesanan', fn () => $this->pesanan ? [
                'id' => $this->pesanan->id,
                'nomor' => $this->pesanan->nomor,
            ] : null),
            'retailer' => $this->whenLoaded('retailer', fn () => $this->retailer ? [
                'id' => $this->retailer->id,
                'kode' => $this->retailer->kode,
                'nama_toko' => $this->retailer->nama_toko,
            ] : null),
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'alasan' => $this->alasan,
            'alasan_ditolak' => $this->alasan_ditolak,
            'jenis_penyelesaian' => $this->jenis_penyelesaian,
            'item' => $this->whenLoaded('item', function (): ?array {
                if (! $this->item) {
                    return null;
                }

                return [
                    'id' => $this->item->id,
                    'item_pesanan_id' => $this->item->item_pesanan_id,
                    'produk_id' => $this->item->produk_id,
                    'produk' => $this->item->relationLoaded('produk') && $this->item->produk ? [
                        'id' => $this->item->produk->id,
                        'kode' => $this->item->produk->kode,
                        'nama' => $this->item->produk->nama,
                        'satuan' => $this->item->produk->satuan,
                    ] : null,
                    'nama_produk_pesanan' => $this->item->relationLoaded('itemPesanan')
                        ? $this->item->itemPesanan?->nama_produk
                        : null,
                    'qty' => $this->item->qty,
                ];
            }),
            'foto_kondisi' => $this->whenLoaded('fotoBukti', fn () => $this->urlFoto($this->fotoBukti->where('jenis', 'kondisi_produk'))),
            'jadwal_jemput' => $this->jadwal_jemput?->toIso8601String(),
            'catatan_jemput' => $this->catatan_jemput,
            'foto_penjemputan' => $this->whenLoaded('fotoBukti', fn () => $this->urlFoto($this->fotoBukti->where('jenis', 'bukti_penjemputan'))),
            'pengaju' => $this->whenLoaded('pengaju', fn () => $this->pengaju?->name),
            'dikonfirmasi_oleh' => $this->whenLoaded('dikonfirmasiOleh', fn () => $this->dikonfirmasiOleh?->name),
            'dikonfirmasi_at' => $this->dikonfirmasi_at?->toIso8601String(),
            'dijemput_at' => $this->dijemput_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /** @param Collection<int, FotoBukti> $foto */
    private function urlFoto(Collection $foto): array
    {
        return $foto->values()->map(fn (FotoBukti $item) => [
            'id' => $item->id,
            'jenis' => $item->jenis,
            'url' => route('api.retur.foto', ['retur' => $this->id, 'fotoBukti' => $item->id]),
            'mime' => $item->mime,
            'ukuran' => $item->ukuran,
        ])->all();
    }
}
