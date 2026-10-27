<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/**
 * Append-only (BR-08, NFR-06): tidak boleh diubah atau dihapus lewat aplikasi.
 */
class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $table = 'audit_logs';

    protected $fillable = [
        'auditable_type',
        'auditable_id',
        'user_id',
        'aksi',
        'status_dari',
        'status_ke',
        'alasan',
        'meta',
    ];

    protected function casts(): array
    {
        return [
            'meta' => 'array',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Audit log tidak boleh diubah.'));
        static::deleting(fn () => throw new LogicException('Audit log tidak boleh dihapus.'));
    }

    public static function catat(
        Model $objek,
        string $aksi,
        ?string $statusDari = null,
        ?string $statusKe = null,
        ?string $alasan = null,
        array $meta = [],
        ?int $userId = null,
    ): self {
        return static::create([
            'auditable_type' => $objek->getMorphClass(),
            'auditable_id' => $objek->getKey(),
            'user_id' => $userId,
            'aksi' => $aksi,
            'status_dari' => $statusDari,
            'status_ke' => $statusKe,
            'alasan' => $alasan,
            'meta' => $meta ?: null,
        ]);
    }
}
