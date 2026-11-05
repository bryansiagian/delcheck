<?php

namespace App\Models;

use App\Enums\StatusRetur;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphMany;

class Retur extends Model
{
    protected $table = 'retur';

    protected $fillable = [
        'nomor',
        'pesanan_id',
        'laporan_id',
        'retailer_id',
        'diajukan_oleh',
        'alasan',
        'status',
        'dikonfirmasi_oleh',
        'dikonfirmasi_at',
        'alasan_ditolak',
        'jadwal_jemput',
        'dijemput_at',
        'bukti_jemput',
        'diterima_gudang_at',
        'tindak_lanjut',
        'selesai_at',
        'jenis_penyelesaian',
        'catatan_jemput',
    ];

    protected function casts(): array
    {
        return [
            'status' => StatusRetur::class,
            'dikonfirmasi_at' => 'datetime',
            'jadwal_jemput' => 'datetime',
            'dijemput_at' => 'datetime',
            'diterima_gudang_at' => 'datetime',
            'selesai_at' => 'datetime',
        ];
    }

    public function pesanan(): BelongsTo
    {
        return $this->belongsTo(Pesanan::class);
    }

    public function retailer(): BelongsTo
    {
        return $this->belongsTo(Retailer::class);
    }

    public function pengaju(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diajukan_oleh');
    }

    public function dikonfirmasiOleh(): BelongsTo
    {
        return $this->belongsTo(User::class, 'dikonfirmasi_oleh');
    }

    /** Satu Return hanya memiliki satu item sesuai unique constraint retur_id. */
    public function item(): HasOne
    {
        return $this->hasOne(ItemRetur::class, 'retur_id');
    }

    /** Foto dapat mencakup kondisi produk maupun bukti penjemputan. */
    public function fotoBukti(): MorphMany
    {
        return $this->morphMany(FotoBukti::class, 'fotoable');
    }
}
