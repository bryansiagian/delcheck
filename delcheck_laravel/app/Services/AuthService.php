<?php

namespace App\Services;

use App\Enums\Peran;
use App\Enums\StatusVerifikasi;
use App\Exceptions\ApiException;
use App\Models\Retailer;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthService
{
    /**
     * Pendaftaran publik: selalu menjadi Retail, nonaktif sampai diverifikasi Admin.
     */
    public function registerRetail(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'] ?? null,
                'phone' => $data['phone'] ?? null,
                'password' => $data['password'],
                'is_active' => false,
            ]);

            $user->assignRole(Peran::Retail->value);

            $retailer = Retailer::create([
                'user_id' => $user->id,
                'wilayah_id' => $data['wilayah_id'] ?? null,
                'kode' => Str::random(20), // sementara, diganti setelah id diketahui
                'nama_toko' => $data['nama_toko'],
                'nama_pemilik' => $data['nama_pemilik'] ?? null,
                'alamat' => $data['alamat'],
                'telepon' => $user->phone,
                'email' => $user->email,
                'status_verifikasi' => StatusVerifikasi::Menunggu,
            ]);

            $retailer->update(['kode' => sprintf('RTL-%06d', $retailer->id)]);

            return $user->load('retailer');
        });
    }

    /**
     * @return array{user: User, token: string}
     */
    public function login(?string $email, ?string $phone, string $password, string $namaPerangkat = 'mobile'): array
    {
        $user = User::query()
            ->when(
                $email,
                fn ($query) => $query->where('email', $email),
                fn ($query) => $query->where('phone', $phone),
            )
            ->first();

        // Pesan sama untuk akun tak ada dan password salah, agar akun tak bisa ditebak.
        if (! $user || ! Hash::check($password, $user->password)) {
            throw new ApiException('Email/nomor telepon atau kata sandi salah.', 401, 'KREDENSIAL_SALAH');
        }

        $this->pastikanBolehLogin($user);

        $user->forceFill(['last_login_at' => now()])->save();

        return [
            'user' => $user->load('retailer'),
            'token' => $user->createToken($namaPerangkat)->plainTextToken,
        ];
    }

    private function pastikanBolehLogin(User $user): void
    {
        $retailer = $user->hasRole(Peran::Retail->value) ? $user->retailer : null;

        if ($retailer?->status_verifikasi === StatusVerifikasi::Menunggu) {
            throw new ApiException('Akun Anda menunggu verifikasi Admin.', 403, 'AKUN_MENUNGGU_VERIFIKASI');
        }

        if ($retailer?->status_verifikasi === StatusVerifikasi::Ditolak) {
            $alasan = $retailer->alasan_ditolak ? ' Alasan: '.$retailer->alasan_ditolak : '';
            throw new ApiException('Pendaftaran Anda ditolak.'.$alasan, 403, 'AKUN_DITOLAK');
        }

        if (! $user->is_active) {
            throw new ApiException('Akun Anda dinonaktifkan. Hubungi Admin.', 403, 'AKUN_NONAKTIF');
        }
    }
}
