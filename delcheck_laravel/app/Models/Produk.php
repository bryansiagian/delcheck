<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Produk extends Model
{
    use SoftDeletes;

    protected $table = 'produk';

    protected $fillable = [
        'kategori_id',
        'kode',
        'nama',
        'deskripsi',
        'satuan',
        'harga',
        'stok_minimum',
        'foto',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'harga' => 'decimal:2',
            'stok_minimum' => 'integer',
            'is_active' => 'boolean',
        ];
    }
}
