<?php

namespace App\Http\Requests;

use App\Models\Produk;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Dipakai untuk tambah (POST) dan ubah (PUT) produk. */
class ProdukRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:produk.kelola
    }

    protected function prepareForValidation(): void
    {
        $kode = $this->input('kode');

        if (is_string($kode)) {
            $this->merge(['kode' => strtoupper(trim($kode))]);
        }
    }

    public function rules(): array
    {
        $produk = $this->route('produk');
        $idSaatIni = $produk instanceof Produk ? $produk->id : $produk;

        return [
            'kode' => [
                'required', 'string', 'max:40',
                'regex:/^[A-Z0-9._\-]+$/',
                // Termasuk produk yang sudah dihapus (soft delete), karena kolom kode unik di database.
                Rule::unique('produk', 'kode')->ignore($idSaatIni),
            ],
            'nama' => ['required', 'string', 'max:255'],
            'deskripsi' => ['nullable', 'string', 'max:2000'],
            'satuan' => ['required', 'string', 'max:20'],
            'harga' => ['required', 'numeric', 'min:0', 'max:9999999999999.99'],
            'stok_minimum' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
            'kategori_id' => ['nullable', 'integer', 'exists:kategori_produk,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'kode.regex' => 'Kode hanya boleh huruf, angka, titik, strip, dan garis bawah (tanpa spasi).',
            'kode.unique' => 'Kode produk sudah dipakai (termasuk oleh produk yang sudah dihapus).',
        ];
    }
}
