<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\Peran;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;

class SalesController extends Controller
{
    use ApiResponse;

    /** GET /api/admin/sales  (pilihan Sales saat menyetujui pendaftaran Retail) */
    public function index(): JsonResponse
    {
        $sales = User::role(Peran::Sales->value)
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'phone']);

        return $this->success($sales);
    }
}
