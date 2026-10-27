<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRetailRequest;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    use ApiResponse;

    public function __construct(private AuthService $auth)
    {
    }

    /** POST /api/auth/register  (publik, khusus Retail) */
    public function register(RegisterRetailRequest $request): JsonResponse
    {
        $user = $this->auth->registerRetail($request->validated());

        return $this->success(
            new UserResource($user),
            'Pendaftaran berhasil. Akun Anda menunggu verifikasi Admin.',
            201,
        );
    }

    /** POST /api/auth/login  (email+password ATAU telepon+password) */
    public function login(LoginRequest $request): JsonResponse
    {
        $hasil = $this->auth->login(
            $request->validated('email'),
            $request->validated('phone'),
            $request->validated('password'),
            $request->validated('device_name') ?? 'mobile',
        );

        return $this->success([
            'token' => $hasil['token'],
            'token_type' => 'Bearer',
            'user' => new UserResource($hasil['user']),
        ], 'Login berhasil.');
    }

    /** POST /api/auth/logout  (mencabut token yang sedang dipakai) */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->success(null, 'Logout berhasil.');
    }

    /** GET /api/auth/me  (data user, peran, dan izin untuk menyusun menu di aplikasi) */
    public function me(Request $request): JsonResponse
    {
        return $this->success(new UserResource($request->user()->load('retailer')));
    }
}
