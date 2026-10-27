<?php

namespace App\Support;

class NomorTelepon
{
    /**
     * Normalisasi nomor telepon Indonesia ke format 62xxxxxxxxxx.
     * 0812-3456-7890 | +62 812 3456 7890 | 812345678 => 628123456789...
     */
    public static function normalisasi(?string $nomor): ?string
    {
        if ($nomor === null) {
            return null;
        }

        $digit = preg_replace('/\D+/', '', $nomor);

        if ($digit === '' || $digit === null) {
            return null;
        }

        if (str_starts_with($digit, '62')) {
            return $digit;
        }

        if (str_starts_with($digit, '0')) {
            return '62'.substr($digit, 1);
        }

        if (str_starts_with($digit, '8')) {
            return '62'.$digit;
        }

        return $digit; // format tak dikenal, biarkan validasi regex yang menolak
    }
}
