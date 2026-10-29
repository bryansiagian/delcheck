<?php

namespace App\Http\Controllers\Api;

use App\Enums\StatusPesanan;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\AlasanPesananRequest;
use App\Http\Requests\BuatPesananRequest;
use App\Http\Requests\KirimPesananRequest;
use App\Http\Resources\PesananResource;
use App\Models\Pesanan;
use App\Models\User;
use App\Services\PesananService;
use App\Traits\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Pesanan produk.
 *  - Retail    : membuat, melihat pesanan tokonya, membatalkan, menerima
 *  - Sales     : melihat semua pesanan, menyetujui / menolak
 *  - Warehouse / Admin : melihat semua pesanan, menyerahkan ke kurir, menandai dikirim
 */
class PesananController extends Controller
{
    use ApiResponse;

    public function __construct(private PesananService $pesanan)
    {
    }

    /** GET /api/pesanan?status=a,b&q=&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'status' => ['nullable', 'string', 'max:200'],
            'q' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $status = collect(explode(',', $data['status'] ?? ''))
            ->map(fn ($s) => trim($s))
            ->filter()
            ->values();

        $dikenal = array_map(fn ($case) => $case->value, StatusPesanan::cases());
        if ($status->diff($dikenal)->isNotEmpty()) {
            throw ValidationException::withMessages(['status' => 'Status tidak dikenal.']);
        }

        $paginator = $this->batasiUntuk(Pesanan::query(), $request->user())
            ->with('retailer:id,kode,nama_toko')
            ->withCount('items')
            ->when($status->isNotEmpty(), fn ($query) => $query->whereIn('status', $status->all()))
            ->when($data['q'] ?? null, function ($query, $q) {
                $query->where(function ($w) use ($q) {
                    $w->where('nomor', 'like', "%{$q}%")
                        ->orWhereHas('retailer', fn ($r) => $r->where('nama_toko', 'like', "%{$q}%"));
                });
            })
            ->orderByDesc('id')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, PesananResource::class);
    }

    /** GET /api/pesanan/{pesanan} */
    public function show(Request $request, Pesanan $pesanan): JsonResponse
    {
        $boleh = $this->batasiUntuk(Pesanan::query()->whereKey($pesanan->id), $request->user())->exists();
        abort_unless($boleh, 404);

        return $this->success(new PesananResource($pesanan->load(PesananService::MUAT)));
    }

    /** POST /api/pesanan   body: items[{produk_id, qty}], catatan */
    public function store(BuatPesananRequest $request): JsonResponse
    {
        $pesanan = $this->pesanan->buat($request->user(), $request->validated());

        return $this->success(new PesananResource($pesanan), 'Pesanan berhasil dibuat.', 201);
    }

    /** POST /api/pesanan/{pesanan}/batalkan   body: alasan  (Retail) */
    public function batalkan(AlasanPesananRequest $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->batalkan($pesanan, $request->validated('alasan'), $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan dibatalkan.');
    }

    /** POST /api/pesanan/{pesanan}/setujui  (Sales) */
    public function setujui(Request $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->setujui($pesanan, $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan disetujui.');
    }

    /** POST /api/pesanan/{pesanan}/tolak   body: alasan  (Sales) */
    public function tolak(AlasanPesananRequest $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->tolak($pesanan, $request->validated('alasan'), $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan ditolak.');
    }

    /** POST /api/pesanan/{pesanan}/proses  (Warehouse/Admin: sudah bersama kurir) */
    public function proses(Request $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->proses($pesanan, $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan diserahkan ke kurir.');
    }

    /** POST /api/pesanan/{pesanan}/kirim  (Warehouse/Admin: dalam perjalanan) */
    public function kirim(KirimPesananRequest $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->kirim($pesanan, $request->validated(), $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan ditandai dalam perjalanan. Stok diperbarui.');
    }

    /** POST /api/pesanan/{pesanan}/terima  (Retail) */
    public function terima(Request $request, Pesanan $pesanan): JsonResponse
    {
        $hasil = $this->pesanan->terima($pesanan, $request->user());

        return $this->success(new PesananResource($hasil), 'Pesanan dikonfirmasi diterima.');
    }

    /**
     * Cakupan data: Sales, Warehouse, dan Admin melihat semua pesanan
     * (retail tidak terikat ke satu sales); Retail hanya pesanan tokonya.
     */
    private function batasiUntuk(Builder $query, User $user): Builder
    {
        if ($user->hasAnyPermission(['pesanan.lihat-semua', 'pesanan.lihat-binaan'])) {
            return $query;
        }

        return $query->where('retailer_id', $user->retailer?->id ?? 0);
    }
}
