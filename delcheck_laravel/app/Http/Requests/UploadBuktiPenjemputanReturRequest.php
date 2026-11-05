<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UploadBuktiPenjemputanReturRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Izin dijaga middleware permission logistik.
    }

    public function rules(): array
    {
        return [
            'foto_penjemputan' => ['required', 'array', 'min:1', 'max:5'],
            'foto_penjemputan.*' => ['required', 'image', 'max:10240'],
        ];
    }
}
