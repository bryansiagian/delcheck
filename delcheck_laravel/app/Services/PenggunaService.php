<?php

namespace App\Services;

use App\Enums\StatusVerifikasi;
use App\Exceptions\ApiException;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/** UC-A08: Admin mengaktifkan / menonaktifkan akun pengguna. */
class PenggunaService
{
    /**
     * Aktifkan akun. Akun Retail yang pendaftarannya belum disetujui TIDAK boleh
     * diaktifkan dari sini, supaya proses verifikasi (UC-A07) tidak terlewati.
     */
    public function aktifkan(User $user): User
    {
        return DB::transaction(function () use ($user) {
            $terkini = User::query()->lockForUpdate()->findOrFail($user->id);

            if ($terkini->is_active) {
                throw new ApiException('Akun ini sudah aktif.', 409, 'AKUN_SUDAH_AKTIF');
            }

            $retailer = $terkini->retailer;
            if ($retailer !== null && $retailer->status_verifikasi !== StatusVerifikasi::Disetujui) {
                throw new ApiException(
                    'Akun toko ini belum disetujui. Proses lewat menu Verifikasi Pendaftaran Retail.',
                    409,
                    'RETAIL_BELUM_DISETUJUI',
                );
            }

            $terkini->update(['is_active' => true]);

            return $terkini->load(['roles', 'retailer']);
        });
    }

    /**
     * Nonaktifkan akun. Admin tidak boleh menonaktifkan akunnya sendiri.
     * Semua token Sanctum dicabut agar pengguna langsung keluar dari semua perangkat.
     */
    public function nonaktifkan(User $user, User $admin): User
    {
        if ($user->is($admin)) {
            throw new ApiException('Anda tidak dapat menonaktifkan akun Anda sendiri.', 403, 'TIDAK_BISA_NONAKTIFKAN_DIRI');
        }

        return DB::transaction(function () use ($user) {
            $terkini = User::query()->lockForUpdate()->findOrFail($user->id);

            if (! $terkini->is_active) {
                throw new ApiException('Akun ini sudah nonaktif.', 409, 'AKUN_SUDAH_NONAKTIF');
            }

            $terkini->update(['is_active' => false]);
            $terkini->tokens()->delete();

            return $terkini->load(['roles', 'retailer']);
        });
    }
}
