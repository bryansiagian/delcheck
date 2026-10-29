<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\MutasiStokRequest;
use App\Http\Resources\MutasiStokResource;
use App\Http\Resources\StokResource;
use App\Models\MutasiStok;
use App\Models\Produk;
use App\Services\StokService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Stok produk (izin stok.kelola: Admin dan Warehouse).
 * Setiap perubahan dicatat di mutasi_stok; stok tidak pernah boleh negatif.
 * Logika perubahan stok ada di StokService (dipakai juga oleh pengiriman pesanan).
 */
class StokController extends Controller
{
    use ApiResponse;

    public function __construct(private StokService $stok)
    {
    }

    /** GET /api/stok?q=&status=menipis&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', Rule::in(['menipis'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $paginator = Produk::denganStok()
            ->when($data['q'] ?? null, function ($query, $q) {
                $query->where(function ($w) use ($q) {
                    $w->where('produk.nama', 'like', "%{$q}%")
                        ->orWhere('produk.kode', 'like', "%{$q}%");
                });
            })
            ->when(
                ($data['status'] ?? null) === 'menipis',
                fn ($query) => $query->whereRaw('COALESCE(stok_produk.jumlah, 0) <= produk.stok_minimum'),
            )
            ->orderBy('produk.nama')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, StokResource::class);
    }

    /** GET /api/stok/{produk} */
    public function show(Produk $produk): JsonResponse
    {
        return $this->success(new StokResource($this->denganStok($produk)));
    }

    /** GET /api/stok/{produk}/mutasi  (riwayat, terbaru dulu) */
    public function riwayat(Request $request, Produk $produk): JsonResponse
    {
        $data = $request->validate([
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $paginator = MutasiStok::query()
            ->with('pembuat:id,name')
            ->where('produk_id', $produk->id)
            ->orderByDesc('id')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, MutasiStokResource::class);
    }

    /** POST /api/stok/{produk}/mutasi   body: tipe (masuk|keluar), jumlah, alasan */
    public function ubah(MutasiStokRequest $request, Produk $produk): JsonResponse
    {
        $data = $request->validated();
        $keluar = $data['tipe'] === 'keluar';

        DB::transaction(function () use ($produk, $data, $request) {
            $this->stok->ubah(
                $produk->id,
                $data['tipe'],
                (int) $data['jumlah'],
                $data['alasan'] ?? null,
                $request->user(),
            );
        });

        return $this->success(
            new StokResource($this->denganStok($produk)),
            $keluar ? 'Stok berhasil dikurangi.' : 'Stok berhasil ditambah.',
            201,
        );
    }

    private function denganStok(Produk $produk): Produk
    {
        return Produk::denganStok()->whereKey($produk->id)->firstOrFail();
    }
}
