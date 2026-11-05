<?php

namespace App\Http\Controllers\Api;

use App\Enums\Peran;
use App\Enums\StatusRetur;
use App\Http\Controllers\Controller;
use App\Http\Requests\BuatDraftReturRequest;
use App\Http\Requests\JadwalkanPenjemputanReturRequest;
use App\Http\Requests\TolakReturRequest;
use App\Http\Requests\UpdateDraftReturRequest;
use App\Http\Requests\UploadBuktiPenjemputanReturRequest;
use App\Http\Resources\ReturResource;
use App\Models\FotoBukti;
use App\Models\Retur;
use App\Models\User;
use App\Services\ReturService;
use App\Traits\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReturController extends Controller
{
    use ApiResponse;

    private const IZIN_LOGISTIK = ['pengiriman.perbarui', 'retur.pantau-logistik'];

    private const STATUS_LOGISTIK = [
        StatusRetur::Disetujui,
        StatusRetur::Dijadwalkan,
        StatusRetur::Dijemput,
    ];

    private const STATUS_SALES = [
        StatusRetur::Diajukan,
        StatusRetur::Disetujui,
        StatusRetur::Ditolak,
        StatusRetur::Dijadwalkan,
        StatusRetur::Dijemput,
    ];

    public function __construct(private ReturService $retur) {}

    /** GET /api/retur?status=&q=&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'status' => ['nullable', Rule::enum(StatusRetur::class)],
            'q' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $paginator = $this->returTerlihat($request->user())
            ->with(ReturService::MUAT)
            ->when($data['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->when($data['q'] ?? null, function (Builder $query, string $q): void {
                $query->where(function (Builder $filter) use ($q): void {
                    $filter->where('nomor', 'like', "%{$q}%")
                        ->orWhereHas('retailer', fn (Builder $retailer) => $retailer->where('nama_toko', 'like', "%{$q}%"))
                        ->orWhereHas('item', function (Builder $item) use ($q): void {
                            $item->whereHas('produk', fn (Builder $produk) => $produk
                                ->where('nama', 'like', "%{$q}%")
                                ->orWhere('kode', 'like', "%{$q}%"))
                                ->orWhereHas('itemPesanan', fn (Builder $itemPesanan) => $itemPesanan
                                    ->where('nama_produk', 'like', "%{$q}%"));
                        });
                });
            })
            ->orderByDesc('id')
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, ReturResource::class);
    }

    /** GET /api/retur/{retur} */
    public function show(Request $request, Retur $retur): JsonResponse
    {
        $hasil = $this->returTerlihat($request->user())
            ->with(ReturService::MUAT)
            ->whereKey($retur->id)
            ->firstOrFail();

        return $this->success(new ReturResource($hasil));
    }

    /** POST /api/retur; multipart foto_kondisi[] bersifat opsional saat draft. */
    public function store(BuatDraftReturRequest $request): JsonResponse
    {
        $data = $request->safe()->except('foto_kondisi');
        $foto = $request->file('foto_kondisi', []);
        $retur = $this->retur->buatDraft($request->user(), $data, is_array($foto) ? $foto : [$foto]);

        return $this->success(new ReturResource($retur), 'Draft Return berhasil dibuat.', 201);
    }

    /** PUT /api/retur/{retur}; multipart foto_kondisi[] mengganti foto kondisi draft. */
    public function update(UpdateDraftReturRequest $request, Retur $retur): JsonResponse
    {
        $data = $request->safe()->except('foto_kondisi');
        $foto = $request->hasFile('foto_kondisi') ? $request->file('foto_kondisi') : null;
        $foto = is_array($foto) ? $foto : ($foto ? [$foto] : null);
        $hasil = $this->retur->perbaruiDraft($retur, $request->user(), $data, $foto);

        return $this->success(new ReturResource($hasil), 'Draft Return berhasil diperbarui.');
    }

    /** DELETE /api/retur/{retur} */
    public function destroy(Request $request, Retur $retur): JsonResponse
    {
        $this->retur->hapusDraft($retur, $request->user());

        return $this->success(null, 'Draft Return berhasil dihapus.');
    }

    /** POST /api/retur/{retur}/ajukan */
    public function ajukan(Request $request, Retur $retur): JsonResponse
    {
        $hasil = $this->retur->ajukan($retur, $request->user());

        return $this->success(new ReturResource($hasil), 'Return berhasil diajukan.');
    }

    /** POST /api/retur/{retur}/setujui */
    public function setujui(Request $request, Retur $retur): JsonResponse
    {
        $hasil = $this->retur->setujui($retur, $request->user());

        return $this->success(new ReturResource($hasil), 'Return disetujui.');
    }

    /** POST /api/retur/{retur}/tolak */
    public function tolak(TolakReturRequest $request, Retur $retur): JsonResponse
    {
        $hasil = $this->retur->tolak($retur, $request->validated('alasan'), $request->user());

        return $this->success(new ReturResource($hasil), 'Return ditolak.');
    }

    /** PUT /api/retur/{retur}/jadwal-penjemputan */
    public function jadwalkan(JadwalkanPenjemputanReturRequest $request, Retur $retur): JsonResponse
    {
        $data = $request->validated();
        $hasil = $this->retur->jadwalkanPenjemputan(
            $retur,
            $data['jadwal_jemput'],
            $data['catatan_jemput'] ?? null,
            $request->user(),
        );

        return $this->success(new ReturResource($hasil), 'Jadwal penjemputan Return berhasil disimpan.');
    }

    /** POST /api/retur/{retur}/bukti-penjemputan; multipart foto_penjemputan[]. */
    public function unggahBukti(UploadBuktiPenjemputanReturRequest $request, Retur $retur): JsonResponse
    {
        $foto = $request->file('foto_penjemputan');
        $hasil = $this->retur->unggahBuktiPenjemputan(
            $retur,
            is_array($foto) ? $foto : [$foto],
            $request->user(),
        );

        return $this->success(new ReturResource($hasil), 'Bukti penjemputan berhasil diunggah. Return ditandai dijemput.');
    }

    /** GET /api/retur/{retur}/foto/{fotoBukti}; path penyimpanan tidak dikirim ke klien. */
    public function foto(Request $request, Retur $retur, FotoBukti $fotoBukti): StreamedResponse
    {
        $terlihat = $this->returTerlihat($request->user())->whereKey($retur->id)->exists();
        abort_unless($terlihat, 404);

        $foto = $retur->fotoBukti()->whereKey($fotoBukti->id)->firstOrFail();
        $disk = Storage::disk((string) config('filesystems.default', 'local'));
        abort_unless($disk->exists($foto->path), 404);

        $mime = is_string($foto->mime) && str_starts_with($foto->mime, 'image/')
            ? $foto->mime
            : 'application/octet-stream';

        return $disk->response($foto->path, null, [
            'Content-Type' => $mime,
            'Content-Disposition' => 'inline; filename="foto-return-'.$foto->id.'"',
            'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    /** Query data sesuai permission aktor, lalu detail/foto memakai query scope yang sama. */
    private function returTerlihat(User $user): Builder
    {
        if ($user->hasPermissionTo('retur.ajukan')) {
            return Retur::query()->where('retailer_id', $user->retailer?->id ?? 0);
        }

        if (
            $user->hasRole(Peran::Sales->value)
            && $user->hasPermissionTo('retur.konfirmasi')
        ) {
            return Retur::query()->whereIn('status', array_map(
                fn (StatusRetur $status) => $status->value,
                self::STATUS_SALES,
            ));
        }

        if ($user->hasAnyPermission(self::IZIN_LOGISTIK)) {
            return Retur::query()->whereIn('status', array_map(
                fn (StatusRetur $status) => $status->value,
                self::STATUS_LOGISTIK,
            ));
        }

        abort(403);
    }
}
