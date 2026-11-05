<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class BuatDraftReturRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Izin dijaga middleware permission:retur.ajukan.
    }

    public function rules(): array
    {
        return [
            'pesanan_id' => ['required', 'integer', 'min:1', 'exists:pesanan,id'],
            'item_pesanan_id' => ['required', 'integer', 'min:1', 'exists:item_pesanan,id'],
            'qty' => ['required', 'integer', 'min:1'],
            'alasan' => ['required', 'string'],
            'jenis_penyelesaian' => ['nullable', 'string', Rule::in(['refund', 'replacement'])],
            'foto_kondisi' => ['sometimes', 'array', 'max:5'],
            'foto_kondisi.*' => ['required', 'image', 'max:10240'],
        ];
    }
}
