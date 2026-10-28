<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Riwayat setiap perubahan stok (jumlah bertanda: + masuk, - keluar). */
class MutasiStok extends Model
{
    protected $table = 'mutasi_stok';

    protected $fillable = [
        'produk_id',
        'tipe',
        'jumlah',
        'stok_sebelum',
        'stok_sesudah',
        'alasan',
        'referensi_type',
        'referensi_id',
        'dibuat_oleh',
    ];

    protected function casts(): array
    {
        return [
            'jumlah' => 'integer',
            'stok_sebelum' => 'integer',
            'stok_sesudah' => 'integer',
        ];
    }

    public function produk(): BelongsTo
    {
        return $this->belongsTo(Produk::class);
    }

    public function pembuat(): BelongsTo
    {
        return $this->belongsTo(User::class, 'dibuat_oleh');
    }

    public function referensi(): MorphTo
    {
        return $this->morphTo();
    }
}
