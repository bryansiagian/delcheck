<?php

namespace App\Enums;

/**
 * Status pesanan (sesuai komentar kolom pesanan.status di migration).
 *
 * Alur yang dipakai MVP:
 *   menunggu_konfirmasi_sales -> dikonfirmasi -> diproses -> dikirim -> diterima
 *                             \-> ditolak       (oleh Sales)
 *   menunggu_konfirmasi_sales -> dibatalkan      (oleh Retail)
 *
 * "diajukan" dan "selesai" belum dipakai (disiapkan untuk pesanan buatan Sales
 * dan penutupan pesanan setelah masa laporan/retur).
 */
enum StatusPesanan: string
{
    case Diajukan = 'diajukan';
    case MenungguKonfirmasiSales = 'menunggu_konfirmasi_sales';
    case Dikonfirmasi = 'dikonfirmasi';
    case Ditolak = 'ditolak';
    case Diproses = 'diproses';
    case Dikirim = 'dikirim';
    case Diterima = 'diterima';
    case Selesai = 'selesai';
    case Dibatalkan = 'dibatalkan';

    public function label(): string
    {
        return match ($this) {
            self::Diajukan => 'Diajukan',
            self::MenungguKonfirmasiSales => 'Menunggu konfirmasi',
            self::Dikonfirmasi => 'Dikonfirmasi',
            self::Ditolak => 'Ditolak',
            self::Diproses => 'Diserahkan ke kurir',
            self::Dikirim => 'Dalam perjalanan',
            self::Diterima => 'Diterima',
            self::Selesai => 'Selesai',
            self::Dibatalkan => 'Dibatalkan',
        };
    }
}
