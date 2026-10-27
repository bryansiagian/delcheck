<?php

namespace App\Http\Requests\Auth;

use App\Support\NomorTelepon;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;

class RegisterRetailRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'email' => $this->filled('email') ? Str::lower(trim($this->input('email'))) : null,
            'phone' => NomorTelepon::normalisasi($this->input('phone')),
        ]);
    }

    /**
     * Field "role" sengaja tidak ada: peran selalu "retail" dan ditetapkan di server.
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'required_without:phone', 'email:rfc', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'required_without:email', 'regex:/^62[0-9]{8,13}$/', 'unique:users,phone'],
            'password' => ['required', 'string', Password::min(8)->letters()->numbers()],

            'nama_toko' => ['required', 'string', 'max:255'],
            'nama_pemilik' => ['nullable', 'string', 'max:255'],
            'alamat' => ['required', 'string', 'max:1000'],
            'wilayah_id' => ['nullable', 'integer', 'exists:wilayah,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.required_without' => 'Isi email atau nomor telepon.',
            'phone.required_without' => 'Isi email atau nomor telepon.',
            'email.unique' => 'Email sudah terdaftar.',
            'phone.unique' => 'Nomor telepon sudah terdaftar.',
            'phone.regex' => 'Format nomor telepon tidak valid.',
        ];
    }
}
