<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\StatusVerifikasi;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SetujuiRetailRequest;
use App\Http\Requests\Admin\TolakRetailRequest;
use App\Http\Resources\RetailerResource;
use App\Models\Retailer;
use App\Services\VerifikasiRetailService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** UC-A07 Verifikasi Pendaftaran Retail (izin: retailer.verifikasi) */
class PendaftaranRetailController extends Controller
{
    use ApiResponse;

    public function __construct(private VerifikasiRetailService $verifikasi)
    {
    }

    /** GET /api/admin/pendaftaran-retail?status=menunggu&q=&per_page=15 */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'status' => ['nullable', Rule::enum(StatusVerifikasi::class)],
            'q' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $paginator = Retailer::query()
            ->with(['user', 'wilayah', 'diverifikasiOleh'])
            ->where('status_verifikasi', $data['status'] ?? StatusVerifikasi::Menunggu->value)
            ->when($data['q'] ?? null, function ($query, $q) {
                $query->where(function ($w) use ($q) {
                    $w->where('nama_toko', 'like', "%{$q}%")
                        ->orWhere('kode', 'like', "%{$q}%")
                        ->orWhere('nama_pemilik', 'like', "%{$q}%")
                        ->orWhere('telepon', 'like', "%{$q}%")
                        ->orWhere('email', 'like', "%{$q}%");
                });
            })
            ->latest()
            ->paginate($data['per_page'] ?? 15);

        return $this->paginated($paginator, RetailerResource::class);
    }

    /** GET /api/admin/pendaftaran-retail/{retailer} */
    public function show(Retailer $retailer): JsonResponse
    {
        $retailer->load(['user', 'wilayah', 'diverifikasiOleh', 'sales']);

        return $this->success(new RetailerResource($retailer));
    }

    /** POST /api/admin/pendaftaran-retail/{retailer}/setujui   body: sales_id */
    public function setujui(SetujuiRetailRequest $request, Retailer $retailer): JsonResponse
    {
        $retailer = $this->verifikasi->setujui($retailer, (int) $request->validated('sales_id'), $request->user());

        return $this->success(new RetailerResource($retailer), 'Pendaftaran disetujui. Toko kini dapat login.');
    }

    /** POST /api/admin/pendaftaran-retail/{retailer}/tolak   body: alasan */
    public function tolak(TolakRetailRequest $request, Retailer $retailer): JsonResponse
    {
        $retailer = $this->verifikasi->tolak($retailer, $request->validated('alasan'), $request->user());

        return $this->success(new RetailerResource($retailer), 'Pendaftaran ditolak.');
    }
}
