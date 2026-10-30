<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\Peran;
use App\Http\Controllers\Controller;
use App\Http\Resources\PenggunaResource;
use App\Models\User;
use App\Services\PenggunaService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** UC-A08 Kelola akun pengguna (izin: pengguna.kelola) */
class PenggunaController extends Controller
{
    use ApiResponse;

    public function __construct(private PenggunaService $pengguna)
    {
    }

    /** GET /api/admin/pengguna?q=&role=sales&aktif=1&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'role' => ['nullable', Rule::enum(Peran::class)],
            'aktif' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $aktif = isset($data['aktif']) ? (bool) $data['aktif'] : null;

        $paginator = User::query()
            ->with(['roles', 'retailer'])
            ->when($data['role'] ?? null, fn ($query, $peran) => $query->role($peran))
            ->when($aktif !== null, fn ($query) => $query->where('is_active', $aktif))
            ->when($data['q'] ?? null, function ($query, $q) {
                $query->where(function ($w) use ($q) {
                    $w->where('name', 'like', "%{$q}%")
                        ->orWhere('email', 'like', "%{$q}%")
                        ->orWhere('phone', 'like', "%{$q}%")
                        ->orWhereHas('retailer', fn ($r) => $r->where('nama_toko', 'like', "%{$q}%"));
                });
            })
            ->orderBy('name')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, PenggunaResource::class);
    }

    /** POST /api/admin/pengguna/{user}/aktifkan */
    public function aktifkan(User $user): JsonResponse
    {
        return $this->success(
            new PenggunaResource($this->pengguna->aktifkan($user)),
            'Akun diaktifkan.',
        );
    }

    /** POST /api/admin/pengguna/{user}/nonaktifkan */
    public function nonaktifkan(Request $request, User $user): JsonResponse
    {
        return $this->success(
            new PenggunaResource($this->pengguna->nonaktifkan($user, $request->user())),
            'Akun dinonaktifkan. Pengguna otomatis keluar dari semua perangkat.',
        );
    }
}
