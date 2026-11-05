<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CatatPengirimanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // akses dijaga role:admin dan permission:pesanan.proses
    }

    protected function prepareForValidation(): void
    {
        if (! $this->filled('tanggal_kirim')) {
            $this->merge(['tanggal_kirim' => today()->toDateString()]);
        }
    }

    public function rules(): array
    {
        return [
            'nama_pengemudi' => ['required', 'string', 'max:120'],
            'telepon_pengemudi' => ['required', 'string', 'max:30'],
            'nomor_kendaraan' => ['required', 'string', 'max:40'],
            'tanggal_kirim' => ['required', 'date_format:Y-m-d'],
            'estimasi_tiba' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:tanggal_kirim'],
            'nomor_surat_jalan' => ['nullable', 'string', 'max:40'],
            'catatan' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'estimasi_tiba.after_or_equal' => 'Estimasi tiba tidak boleh sebelum tanggal kirim.',
        ];
    }
}
