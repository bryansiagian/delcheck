<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WilayahResource;
use App\Models\Wilayah;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class WilayahController extends Controller
{
    use ApiResponse;

    /** GET /api/wilayah  (publik; dipakai form pendaftaran Retail) */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'tingkat' => ['nullable', Rule::in(['provinsi', 'kota', 'kecamatan'])],
            'parent_id' => ['nullable', 'integer'],
            'q' => ['nullable', 'string', 'max:100'],
        ]);

        $wilayah = Wilayah::query()
            ->when($data['tingkat'] ?? null, fn ($query, $nilai) => $query->where('tingkat', $nilai))
            ->when($data['parent_id'] ?? null, fn ($query, $nilai) => $query->where('parent_id', $nilai))
            ->when($data['q'] ?? null, fn ($query, $nilai) => $query->where('nama', 'like', "%{$nilai}%"))
            ->orderBy('nama')
            ->limit(500)
            ->get();

        return $this->success(WilayahResource::collection($wilayah));
    }
}
