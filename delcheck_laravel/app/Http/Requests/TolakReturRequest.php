<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class TolakReturRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Izin dijaga middleware permission:retur.konfirmasi.
    }

    public function rules(): array
    {
        return [
            'alasan' => ['required', 'string', 'min:1'],
        ];
    }
}
