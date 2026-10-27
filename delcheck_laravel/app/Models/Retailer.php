<?php

namespace App\Models;

use App\Enums\StatusVerifikasi;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Retailer extends Model
{
    use SoftDeletes;

    protected $table = 'retailers';

    protected $fillable = [
        'user_id',
        'wilayah_id',
        'kode',
        'nama_toko',
        'nama_pemilik',
        'alamat',
        'telepon',
        'email',
        'latitude',
        'longitude',
        'is_active',
        'status_verifikasi',
        'diverifikasi_oleh',
        'diverifikasi_at',
        'alasan_ditolak',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
            'status_verifikasi' => StatusVerifikasi::class,
            'diverifikasi_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function diverifikasiOleh(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diverifikasi_oleh');
    }
}
