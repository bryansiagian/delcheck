<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateDraftReturRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Izin dan kepemilikan diperiksa oleh middleware dan Service.
    }

    public function rules(): array
    {
        return [
            'pesanan_id' => ['sometimes', 'required', 'integer', 'min:1', 'exists:pesanan,id'],
            'item_pesanan_id' => ['sometimes', 'required', 'integer', 'min:1', 'exists:item_pesanan,id'],
            'qty' => ['sometimes', 'required', 'integer', 'min:1'],
            'alasan' => ['sometimes', 'required', 'string'],
            'jenis_penyelesaian' => ['sometimes', 'nullable', 'string', Rule::in(['refund', 'replacement'])],
            'foto_kondisi' => ['sometimes', 'array', 'max:5'],
            'foto_kondisi.*' => ['required', 'image', 'max:10240'],
        ];
    }
}
