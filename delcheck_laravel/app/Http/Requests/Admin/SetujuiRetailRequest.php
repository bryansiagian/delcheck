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

    /**
     * sales_id OPSIONAL: retail tidak terikat ke satu sales.
     * Kalau tetap dikirim, harus berupa user Sales yang aktif.
     */
    public function rules(): array
    {
        return [
            'sales_id' => ['bail', 'nullable', 'integer', function (string $attribute, mixed $value, Closure $fail) {
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
}
