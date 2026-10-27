<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

/**
 * Error bisnis yang langsung dirender sebagai JSON.
 * $kode berupa string stabil agar aplikasi mobile bisa bercabang tanpa membaca pesan.
 */
class ApiException extends Exception
{
    public function __construct(
        string $message,
        private int $status = 400,
        private ?string $kode = null,
        private array $errors = [],
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return response()->json(array_filter([
            'success' => false,
            'message' => $this->getMessage(),
            'kode' => $this->kode,
            'errors' => $this->errors ?: null,
        ], fn ($nilai) => $nilai !== null), $this->status);
    }
}
