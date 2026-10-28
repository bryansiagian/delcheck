<?php

namespace App\Services;

use App\Enums\StatusVerifikasi;
use App\Exceptions\ApiException;
use App\Models\AuditLog;
use App\Models\Retailer;
use App\Models\SalesAssignment;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class VerifikasiRetailService
{
    /**
     * Setujui pendaftaran: toko menjadi aktif dan akun bisa login.
     *
     * Penugasan Sales bersifat OPSIONAL (retail tidak terikat ke satu sales).
     * Baris sales_assignments hanya dibuat jika $salesId diberikan.
     */
    public function setujui(Retailer $retailer, ?int $salesId, User $admin): Retailer
    {
        return DB::transaction(function () use ($retailer, $salesId, $admin) {
            $retailer = $this->kunciDanPastikanMenunggu($retailer);

            $retailer->update([
                'status_verifikasi' => StatusVerifikasi::Disetujui,
                'diverifikasi_oleh' => $admin->id,
                'diverifikasi_at' => now(),
                'alasan_ditolak' => null,
            ]);

            $retailer->user?->update(['is_active' => true]);

            if ($salesId !== null) {
                SalesAssignment::updateOrCreate(
                    ['sales_id' => $salesId, 'retailer_id' => $retailer->id],
                    ['ditugaskan_oleh' => $admin->id, 'mulai' => today(), 'selesai' => null, 'is_active' => true],
                );
            }

            AuditLog::catat(
                $retailer,
                'verifikasi_disetujui',
                StatusVerifikasi::Menunggu->value,
                StatusVerifikasi::Disetujui->value,
                null,
                $salesId !== null ? ['sales_id' => $salesId] : [],
                $admin->id,
            );

            return $retailer->load(['user', 'wilayah', 'diverifikasiOleh', 'sales']);
        });
    }

    /**
     * Tolak pendaftaran. Alasan wajib (BR-06). Akun tetap nonaktif.
     */
    public function tolak(Retailer $retailer, string $alasan, User $admin): Retailer
    {
        return DB::transaction(function () use ($retailer, $alasan, $admin) {
            $retailer = $this->kunciDanPastikanMenunggu($retailer);

            $retailer->update([
                'status_verifikasi' => StatusVerifikasi::Ditolak,
                'diverifikasi_oleh' => $admin->id,
                'diverifikasi_at' => now(),
                'alasan_ditolak' => $alasan,
            ]);

            AuditLog::catat(
                $retailer,
                'verifikasi_ditolak',
                StatusVerifikasi::Menunggu->value,
                StatusVerifikasi::Ditolak->value,
                $alasan,
                [],
                $admin->id,
            );

            return $retailer->load(['user', 'wilayah', 'diverifikasiOleh', 'sales']);
        });
    }

    /** Kunci baris agar dua Admin tidak memproses pendaftaran yang sama bersamaan. */
    private function kunciDanPastikanMenunggu(Retailer $retailer): Retailer
    {
        $terkini = Retailer::query()->lockForUpdate()->findOrFail($retailer->id);

        if ($terkini->status_verifikasi !== StatusVerifikasi::Menunggu) {
            throw new ApiException('Pendaftaran ini sudah diproses.', 409, 'PENDAFTARAN_SUDAH_DIPROSES');
        }

        return $terkini;
    }
}
