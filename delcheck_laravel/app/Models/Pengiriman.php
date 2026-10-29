<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pengiriman extends Model
{
    protected $table = 'pengiriman';

    protected $fillable = [
        'pesanan_id',
        'nomor_surat_jalan',
        'status',
        'tanggal_kirim',
        'estimasi_tiba',
        'diterima_at',
        'catatan',
        'diperbarui_oleh',
    ];

    protected function casts(): array
    {
        return [
            'tanggal_kirim' => 'date',
            'estimasi_tiba' => 'date',
            'diterima_at' => 'datetime',
        ];
    }

    public function pesanan(): BelongsTo
    {
        return $this->belongsTo(Pesanan::class);
    }
}
