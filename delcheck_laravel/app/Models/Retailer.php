<?php

namespace App\Models;

use App\Enums\StatusVerifikasi;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
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

    public function wilayah(): BelongsTo
    {
        return $this->belongsTo(Wilayah::class);
    }

    public function diverifikasiOleh(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diverifikasi_oleh');
    }

    /** Sales yang aktif ditugaskan ke toko ini (BR-05). */
    public function sales(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'sales_assignments', 'retailer_id', 'sales_id')
            ->wherePivot('is_active', true)
            ->withPivot(['mulai', 'selesai', 'is_active'])
            ->withTimestamps();
    }
}
