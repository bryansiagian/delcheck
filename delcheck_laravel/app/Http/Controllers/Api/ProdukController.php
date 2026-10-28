<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProdukRequest;
use App\Http\Resources\ProdukResource;
use App\Models\Produk;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Katalog produk.
 *  - Lihat  : izin produk.lihat   (Retail & Sales hanya melihat produk aktif, BR-02)
 *  - Kelola : izin produk.kelola  (Admin & Warehouse)
 */
class ProdukController extends Controller
{
    use ApiResponse;

    private const IZIN_KELOLA = 'produk.kelola';

    /** GET /api/produk?q=&status=aktif|nonaktif&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', Rule::in(['aktif', 'nonaktif'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $bisaKelola = $request->user()->hasPermissionTo(self::IZIN_KELOLA);

        $paginator = Produk::query()
            ->when(! $bisaKelola, fn ($query) => $query->where('is_active', true))
            ->when(
                $bisaKelola && isset($data['status']),
                fn ($query) => $query->where('is_active', $data['status'] === 'aktif'),
            )
            ->when($data['q'] ?? null, function ($query, $q) {
                $query->where(function ($w) use ($q) {
                    $w->where('nama', 'like', "%{$q}%")
                        ->orWhere('kode', 'like', "%{$q}%");
                });
            })
            ->orderBy('nama')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, ProdukResource::class);
    }

    /** GET /api/produk/{produk} */
    public function show(Request $request, Produk $produk): JsonResponse
    {
        $bisaKelola = $request->user()->hasPermissionTo(self::IZIN_KELOLA);

        abort_unless($bisaKelola || $produk->is_active, 404);

        return $this->success(new ProdukResource($produk));
    }

    /** POST /api/produk */
    public function store(ProdukRequest $request): JsonResponse
    {
        $produk = Produk::create($this->dataTersaring($request));

        return $this->success(new ProdukResource($produk), 'Produk berhasil ditambahkan.', 201);
    }

    /** PUT /api/produk/{produk} */
    public function update(ProdukRequest $request, Produk $produk): JsonResponse
    {
        $produk->update($this->dataTersaring($request));

        return $this->success(new ProdukResource($produk->refresh()), 'Produk berhasil diperbarui.');
    }

    /** DELETE /api/produk/{produk}  (soft delete; riwayat pesanan tidak rusak) */
    public function destroy(Produk $produk): JsonResponse
    {
        $produk->delete();

        return $this->success(null, 'Produk berhasil dihapus.');
    }

    /** Nilai bawaan untuk kolom yang tidak boleh null di database. */
    private function dataTersaring(ProdukRequest $request): array
    {
        $data = $request->validated();
        $data['stok_minimum'] = $data['stok_minimum'] ?? 0;
        $data['is_active'] = $data['is_active'] ?? true;

        return $data;
    }
}
