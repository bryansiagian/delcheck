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
     * - Boleh dari status Menunggu (setujui biasa) atau Ditolak (setujui ulang).
     * - Penugasan Sales bersifat OPSIONAL (retail tidak terikat ke satu sales);
     *   baris sales_assignments hanya dibuat jika $salesId diberikan.
     */
    public function setujui(Retailer $retailer, ?int $salesId, User $admin): Retailer
    {
        return DB::transaction(function () use ($retailer, $salesId, $admin) {
            $retailer = $this->kunciDanPastikanStatus(
                $retailer,
                [StatusVerifikasi::Menunggu, StatusVerifikasi::Ditolak],
            );

            // Simpan status asal (menunggu/ditolak) untuk audit log.
            $statusAsal = $retailer->status_verifikasi;

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
                $statusAsal->value,
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
     * Hanya untuk pendaftaran yang masih Menunggu.
     */
    public function tolak(Retailer $retailer, string $alasan, User $admin): Retailer
    {
        return DB::transaction(function () use ($retailer, $alasan, $admin) {
            $retailer = $this->kunciDanPastikanStatus($retailer, [StatusVerifikasi::Menunggu]);

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

    /**
     * Kunci baris agar dua Admin tidak memproses pendaftaran yang sama bersamaan,
     * lalu pastikan statusnya termasuk yang diizinkan untuk aksi ini.
     *
     * @param  array<int, StatusVerifikasi>  $diizinkan
     */
    private function kunciDanPastikanStatus(Retailer $retailer, array $diizinkan): Retailer
    {
        $terkini = Retailer::query()->lockForUpdate()->findOrFail($retailer->id);

        if (! in_array($terkini->status_verifikasi, $diizinkan, true)) {
            throw new ApiException('Pendaftaran ini sudah diproses.', 409, 'PENDAFTARAN_SUDAH_DIPROSES');
        }

        return $terkini;
    }
}
