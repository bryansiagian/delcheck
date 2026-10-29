<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** Dipakai untuk menolak dan membatalkan pesanan (alasan wajib, BR-06). */
class AlasanPesananRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'alasan' => ['required', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'alasan.required' => 'Alasan wajib diisi.',
        ];
    }
}
