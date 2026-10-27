<?php

use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::post('/pesanan/{pesanan}/proses', [PesananController::class, 'proses'])
        ->middleware('permission:pesanan.proses');
});
