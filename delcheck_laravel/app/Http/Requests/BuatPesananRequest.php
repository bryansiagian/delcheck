<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class BuatPesananRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:pesanan.buat
    }

    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'min:1', 'max:50'],
            'items.*.produk_id' => ['required', 'integer', 'distinct', 'exists:produk,id'],
            'items.*.qty' => ['required', 'integer', 'min:1', 'max:100000'],
            'catatan' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'items.required' => 'Pilih minimal satu produk.',
            'items.min' => 'Pilih minimal satu produk.',
            'items.*.produk_id.distinct' => 'Produk yang sama tidak boleh dipilih dua kali.',
            'items.*.produk_id.exists' => 'Produk tidak ditemukan.',
            'items.*.qty.min' => 'Jumlah minimal 1.',
        ];
    }
}
