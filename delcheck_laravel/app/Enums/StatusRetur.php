<?php

namespace App\Enums;

/**
 * Status pengajuan Return.
 *
 * Alur normal: draft -> diajukan -> disetujui -> dijadwalkan -> dijemput.
 * Alur penolakan: draft -> diajukan -> ditolak. Ditolak adalah status akhir;
 * pengajuan ulang dibuat sebagai record baru.
 *
 * Nilai enum ini disimpan sebagai string/varchar di database, bukan native enum.
 */
enum StatusRetur: string
{
    case Draft = 'draft';
    case Diajukan = 'diajukan';
    case Ditolak = 'ditolak';
    case Disetujui = 'disetujui';
    case Dijadwalkan = 'dijadwalkan';
    case Dijemput = 'dijemput';

    public function label(): string
    {
        return match ($this) {
            self::Draft => 'Draft',
            self::Diajukan => 'Diajukan',
            self::Ditolak => 'Ditolak',
            self::Disetujui => 'Disetujui',
            self::Dijadwalkan => 'Dijadwalkan',
            self::Dijemput => 'Dijemput',
        };
    }
}
