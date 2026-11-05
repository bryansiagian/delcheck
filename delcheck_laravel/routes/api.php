<?php

use App\Http\Controllers\Api\Admin\PendaftaranRetailController;
use App\Http\Controllers\Api\Admin\PenggunaController;
use App\Http\Controllers\Api\Admin\SalesController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PesananController;
use App\Http\Controllers\Api\ProdukController;
use App\Http\Controllers\Api\ReturController;
use App\Http\Controllers\Api\StokController;
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
// Endpoint pilihan Sales tetap bisa dipakai Admin pengguna dan Sales.
Route::middleware(['auth:sanctum', 'permission:pengguna.kelola|retailer.verifikasi'])
    ->prefix('admin')
    ->group(function () {
        Route::get('sales', [SalesController::class, 'index']);
    });

Route::middleware(['auth:sanctum', 'permission:retailer.lihat-daftar'])
    ->prefix('admin')
    ->group(function () {
        Route::get('pendaftaran-retail', [PendaftaranRetailController::class, 'index']);
        Route::get('pendaftaran-retail/{retailer}', [PendaftaranRetailController::class, 'show']);
    });

Route::middleware(['auth:sanctum', 'permission:retailer.verifikasi'])
    ->prefix('admin')
    ->group(function () {
        Route::post('pendaftaran-retail/{retailer}/setujui', [PendaftaranRetailController::class, 'setujui']);
        Route::post('pendaftaran-retail/{retailer}/tolak', [PendaftaranRetailController::class, 'tolak']);
    });

Route::middleware(['auth:sanctum', 'permission:pengguna.kelola'])
    ->prefix('admin')
    ->group(function () {
        Route::get('pengguna', [PenggunaController::class, 'index']);
        Route::post('pengguna/{user}/aktifkan', [PenggunaController::class, 'aktifkan']);
        Route::post('pengguna/{user}/nonaktifkan', [PenggunaController::class, 'nonaktifkan']);
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

// ------------------------------------------------------------------ stok
Route::middleware(['auth:sanctum', 'permission:stok.kelola'])
    ->prefix('stok')
    ->group(function () {
        Route::get('/', [StokController::class, 'index']);
        Route::get('{produk}', [StokController::class, 'show']);
        Route::get('{produk}/mutasi', [StokController::class, 'riwayat']);
        Route::post('{produk}/mutasi', [StokController::class, 'ubah']);
    });

// --------------------------------------------------------------- pesanan
Route::middleware('auth:sanctum')
    ->prefix('pesanan')
    ->group(function () {
        $lihat = 'permission:pesanan.lihat-semua|pesanan.lihat-binaan|pesanan.lihat-sendiri';

        Route::get('/', [PesananController::class, 'index'])->middleware($lihat);
        Route::get('{pesanan}', [PesananController::class, 'show'])->middleware($lihat);

        // Retail
        Route::post('/', [PesananController::class, 'store'])->middleware('permission:pesanan.buat');
        Route::post('{pesanan}/batalkan', [PesananController::class, 'batalkan'])->middleware('permission:pesanan.buat');
        Route::post('{pesanan}/terima', [PesananController::class, 'terima'])
            ->middleware(['role:retail', 'permission:pesanan.terima']);

        // Sales
        Route::post('{pesanan}/setujui', [PesananController::class, 'setujui'])->middleware('permission:pesanan.konfirmasi');
        Route::post('{pesanan}/tolak', [PesananController::class, 'tolak'])->middleware('permission:pesanan.konfirmasi');

        // Admin saja; role guard juga mencegah akses dari permission langsung.
        Route::post('{pesanan}/catat-pengiriman', [PesananController::class, 'catatPengiriman'])
            ->middleware(['role:admin', 'permission:pesanan.proses']);
        Route::post('{pesanan}/tandai-jalan', [PesananController::class, 'tandaiJalan'])
            ->middleware(['role:admin', 'permission:pengiriman.perbarui']);
    });

// ------------------------------------------------------------------- Return
Route::middleware([
    'auth:sanctum',
    'permission:retur.ajukan|retur.konfirmasi|pengiriman.perbarui|retur.pantau-logistik',
])->prefix('retur')->group(function () {
    Route::get('/', [ReturController::class, 'index']);
    Route::get('{retur}', [ReturController::class, 'show']);
    Route::get('{retur}/foto/{fotoBukti}', [ReturController::class, 'foto'])->name('api.retur.foto');
});

Route::middleware(['auth:sanctum', 'permission:retur.ajukan'])
    ->prefix('retur')
    ->group(function () {
        Route::post('/', [ReturController::class, 'store']);
        Route::put('{retur}', [ReturController::class, 'update']);
        Route::delete('{retur}', [ReturController::class, 'destroy']);
        Route::post('{retur}/ajukan', [ReturController::class, 'ajukan']);
    });

Route::middleware(['auth:sanctum', 'permission:retur.konfirmasi'])
    ->prefix('retur')
    ->group(function () {
        Route::post('{retur}/setujui', [ReturController::class, 'setujui']);
        Route::post('{retur}/tolak', [ReturController::class, 'tolak']);
    });

Route::middleware(['auth:sanctum', 'permission:pengiriman.perbarui|retur.pantau-logistik'])
    ->prefix('retur')
    ->group(function () {
        Route::put('{retur}/jadwal-penjemputan', [ReturController::class, 'jadwalkan']);
        Route::post('{retur}/bukti-penjemputan', [ReturController::class, 'unggahBukti']);
    });
