<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StokProduk extends Model
{
    protected $table = 'stok_produk';

    protected $fillable = ['produk_id', 'jumlah'];

    protected function casts(): array
    {
        return ['jumlah' => 'integer'];
    }

    public function produk(): BelongsTo
    {
        return $this->belongsTo(Produk::class);
    }
}
