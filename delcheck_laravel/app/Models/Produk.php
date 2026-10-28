<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;

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

    public function stok(): HasOne
    {
        return $this->hasOne(StokProduk::class, 'produk_id');
    }

    /**
     * Gabungkan jumlah stok sebagai kolom `stok_jumlah` (0 jika belum ada baris stok).
     * Dipakai daftar stok agar tidak terjadi query N+1.
     */
    public function scopeDenganStok(Builder $query): Builder
    {
        return $query
            ->leftJoin('stok_produk', 'stok_produk.produk_id', '=', 'produk.id')
            ->select('produk.*', DB::raw('COALESCE(stok_produk.jumlah, 0) as stok_jumlah'));
    }
}
