<?php

use App\Http\Controllers\Api\Admin\PendaftaranRetailController;
use App\Http\Controllers\Api\Admin\SalesController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProdukController;
use App\Http\Controllers\Api\WilayahController;
use Illuminate\Support\Facades\Route;

// ---------------------------------------------------------------- publik
Route::get('wilayah', [WilayahController::class, 'index'])->middleware('throttle:60,1');

Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
    });
});

// ----------------------------------------------------------------- admin
Route::middleware(['auth:sanctum', 'permission:retailer.verifikasi'])
    ->prefix('admin')
    ->group(function () {
        Route::get('sales', [SalesController::class, 'index']);

        Route::get('pendaftaran-retail', [PendaftaranRetailController::class, 'index']);
        Route::get('pendaftaran-retail/{retailer}', [PendaftaranRetailController::class, 'show']);
        Route::post('pendaftaran-retail/{retailer}/setujui', [PendaftaranRetailController::class, 'setujui']);
        Route::post('pendaftaran-retail/{retailer}/tolak', [PendaftaranRetailController::class, 'tolak']);
    });

// ---------------------------------------------------------------- produk
Route::middleware('auth:sanctum')
    ->prefix('produk')
    ->group(function () {
        Route::middleware('permission:produk.lihat')->group(function () {
            Route::get('/', [ProdukController::class, 'index']);
            Route::get('{produk}', [ProdukController::class, 'show']);
        });

        Route::middleware('permission:produk.kelola')->group(function () {
            Route::post('/', [ProdukController::class, 'store']);
            Route::put('{produk}', [ProdukController::class, 'update']);
            Route::delete('{produk}', [ProdukController::class, 'destroy']);
        });
    });
