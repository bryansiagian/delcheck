<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class KirimPesananRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:pengiriman.perbarui
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
            'tanggal_kirim' => ['required', 'date_format:Y-m-d'],
            'estimasi_tiba' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:tanggal_kirim'],
            // Nomor resi / surat jalan dari kurir (kurir berada di luar sistem).
            'nomor_surat_jalan' => ['nullable', 'string', 'max:40'],
            // Catatan bebas, mis. nama kurir atau jasa pengiriman.
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
