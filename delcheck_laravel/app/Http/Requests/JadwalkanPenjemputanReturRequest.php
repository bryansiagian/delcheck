<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class JadwalkanPenjemputanReturRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Izin dijaga middleware permission logistik.
    }

    public function rules(): array
    {
        return [
            'jadwal_jemput' => ['required', 'date', 'regex:/\d{1,2}:\d{2}/'],
            'catatan_jemput' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
