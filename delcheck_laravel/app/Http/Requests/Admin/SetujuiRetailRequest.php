<?php

namespace App\Http\Requests\Admin;

use App\Enums\Peran;
use App\Models\User;
use Closure;
use Illuminate\Foundation\Http\FormRequest;

class SetujuiRetailRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // izin dijaga middleware permission:retailer.verifikasi
    }

    public function rules(): array
    {
        return [
            'sales_id' => ['bail', 'required', 'integer', function (string $attribute, mixed $value, Closure $fail) {
                $valid = User::role(Peran::Sales->value)
                    ->where('is_active', true)
                    ->whereKey($value)
                    ->exists();

                if (! $valid) {
                    $fail('Sales tidak ditemukan atau tidak aktif.');
                }
            }],
        ];
    }

    public function messages(): array
    {
        return [
            'sales_id.required' => 'Pilih Sales yang akan menangani toko ini.',
        ];
    }
}
