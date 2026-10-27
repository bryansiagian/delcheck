<?php

namespace App\Traits;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;

trait ApiResponse
{
    protected function success(mixed $data = null, string $message = 'Berhasil.', int $status = 200): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
        ], $status);
    }

    protected function error(string $message, int $status = 400, mixed $errors = null): JsonResponse
    {
        return response()->json(array_filter([
            'success' => false,
            'message' => $message,
            'errors' => $errors,
        ], fn ($nilai) => $nilai !== null), $status);
    }

    /**
     * Daftar berhalaman: data.items + data.meta
     *
     * @param  class-string<\Illuminate\Http\Resources\Json\JsonResource>  $resourceClass
     */
    protected function paginated(LengthAwarePaginator $paginator, string $resourceClass, string $message = 'Berhasil.'): JsonResponse
    {
        return $this->success([
            'items' => $resourceClass::collection($paginator->getCollection()),
            'meta' => [
                'halaman' => $paginator->currentPage(),
                'per_halaman' => $paginator->perPage(),
                'total' => $paginator->total(),
                'halaman_terakhir' => $paginator->lastPage(),
            ],
        ], $message);
    }
}
