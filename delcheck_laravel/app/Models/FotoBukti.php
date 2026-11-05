<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class FotoBukti extends Model
{
    protected $table = 'foto_bukti';

    protected $fillable = [
        'fotoable_type',
        'fotoable_id',
        'jenis',
        'path',
        'nama_asli',
        'mime',
        'ukuran',
        'diunggah_oleh',
    ];

    protected function casts(): array
    {
        return [
            'ukuran' => 'integer',
        ];
    }

    public function fotoable(): MorphTo
    {
        return $this->morphTo();
    }

    public function pengunggah(): BelongsTo
    {
        return $this->belongsTo(User::class, 'diunggah_oleh');
    }
}
