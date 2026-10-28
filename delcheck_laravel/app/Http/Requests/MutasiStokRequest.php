<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Tambah (masuk) atau kurangi (keluar) stok satu produk. */
class MutasiStokRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:stok.kelola
    }

    public function rules(): array
    {
        return [
            'tipe' => ['required', Rule::in(['masuk', 'keluar'])],
            'jumlah' => ['required', 'integer', 'min:1', 'max:1000000'],
            // Alasan wajib saat mengurangi stok (jejak audit).
            'alasan' => ['nullable', 'required_if:tipe,keluar', 'string', 'max:255'],
        ];
    }

    public function messages(): array
    {
        return [
            'tipe.in' => 'Tipe harus masuk atau keluar.',
            'jumlah.min' => 'Jumlah minimal 1.',
            'alasan.required_if' => 'Alasan wajib diisi saat mengurangi stok.',
        ];
    }
}
