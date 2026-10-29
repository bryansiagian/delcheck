<?php

namespace App\Models;

use App\Enums\StatusPesanan;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Pesanan extends Model
{
    protected $table = 'pesanan';

    protected $fillable = [
        'nomor',
        'retailer_id',
        'sales_id',
        'sumber',
        'dibuat_oleh',
        'status',
        'total',
        'catatan',
        'dikonfirmasi_oleh',
        'dikonfirmasi_at',
        'alasan_ditolak',
        'diproses_oleh',
        'diproses_at',
        'dikirim_at',
        'diterima_oleh',
        'diterima_at',
        'selesai_at',
        'dibatalkan_oleh',
        'dibatalkan_at',
        'alasan_batal',
    ];

    protected function casts(): array
    {
        return [
            'status' => StatusPesanan::class,
            'total' => 'decimal:2',
            'dikonfirmasi_at' => 'datetime',
            'diproses_at' => 'datetime',
            'dikirim_at' => 'datetime',
            'diterima_at' => 'datetime',
            'selesai_at' => 'datetime',
            'dibatalkan_at' => 'datetime',
        ];
    }

    public function retailer(): BelongsTo
    {
        return $this->belongsTo(Retailer::class);
    }

    /** Sales yang mengonfirmasi / menolak pesanan. */
    public function sales(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sales_id');
    }

    public function pembuat(): BelongsTo
    {
        return $this->belongsTo(User::class, 'dibuat_oleh');
    }

    public function items(): HasMany
    {
        return $this->hasMany(ItemPesanan::class);
    }

    public function pengiriman(): HasMany
    {
        return $this->hasMany(Pengiriman::class);
    }
}
