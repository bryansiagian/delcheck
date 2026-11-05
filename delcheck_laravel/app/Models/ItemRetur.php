<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ItemRetur extends Model
{
    protected $table = 'item_retur';

    protected $fillable = [
        'retur_id',
        'item_pesanan_id',
        'produk_id',
        'qty',
    ];

    protected function casts(): array
    {
        return [
            'qty' => 'integer',
        ];
    }

    public function retur(): BelongsTo
    {
        return $this->belongsTo(Retur::class, 'retur_id');
    }

    public function itemPesanan(): BelongsTo
    {
        return $this->belongsTo(ItemPesanan::class, 'item_pesanan_id');
    }

    public function produk(): BelongsTo
    {
        return $this->belongsTo(Produk::class, 'produk_id');
    }
}
