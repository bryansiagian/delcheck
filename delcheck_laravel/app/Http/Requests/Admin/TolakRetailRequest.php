<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class TolakRetailRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:retailer.verifikasi
    }

    public function rules(): array
    {
        return [
            'alasan' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'alasan.required' => 'Alasan penolakan wajib diisi.',
        ];
    }
}
