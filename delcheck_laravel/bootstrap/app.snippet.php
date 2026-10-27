<?php

/*
 * BUKAN file pengganti. Gabungkan isi ini ke bootstrap/app.php yang sudah ada:
 *  - tambahkan semua "use" di bawah ke bagian atas file,
 *  - ganti isi withExceptions(...) dengan yang di bawah,
 *  - isi withMiddleware(...) (alias Spatie) sudah Anda punya dari langkah sebelumnya.
 */

use App\Exceptions\ApiException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Spatie\Permission\Exceptions\UnauthorizedException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

// ->withExceptions(function (Exceptions $exceptions) {
function (Exceptions $exceptions) {
    // Semua request /api/* selalu dijawab JSON, walau klien lupa header Accept.
    $exceptions->shouldRenderJsonWhen(
        fn (Request $request, Throwable $e) => $request->is('api/*') || $request->expectsJson()
    );

    // Error bisnis yang disengaja tidak perlu masuk log.
    $exceptions->dontReport(ApiException::class);

    $exceptions->render(function (ValidationException $e, Request $request) {
        if ($request->is('api/*')) {
            return response()->json([
                'success' => false,
                'message' => 'Data yang dikirim tidak valid.',
                'errors' => $e->errors(),
            ], 422);
        }
    });

    $exceptions->render(function (AuthenticationException $e, Request $request) {
        if ($request->is('api/*')) {
            return response()->json([
                'success' => false,
                'message' => 'Silakan login terlebih dahulu.',
                'kode' => 'BELUM_LOGIN',
            ], 401);
        }
    });

    // Spatie: role/permission tidak cukup
    $exceptions->render(function (UnauthorizedException $e, Request $request) {
        if ($request->is('api/*')) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki akses untuk tindakan ini.',
                'kode' => 'TIDAK_PUNYA_AKSES',
            ], 403);
        }
    });

    $exceptions->render(function (NotFoundHttpException $e, Request $request) {
        if ($request->is('api/*')) {
            return response()->json([
                'success' => false,
                'message' => 'Data tidak ditemukan.',
                'kode' => 'TIDAK_DITEMUKAN',
            ], 404);
        }
    });

    $exceptions->render(function (ThrottleRequestsException $e, Request $request) {
        if ($request->is('api/*')) {
            return response()->json([
                'success' => false,
                'message' => 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.',
                'kode' => 'TERLALU_BANYAK_PERMINTAAN',
            ], 429);
        }
    });
}
// })
