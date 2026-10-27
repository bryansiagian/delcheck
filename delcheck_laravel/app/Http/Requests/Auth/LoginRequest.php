<?php

namespace App\Http\Requests\Auth;

use App\Support\NomorTelepon;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;

class LoginRequest extends FormRequest
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
     * Login memakai SALAH SATU: email + password, atau telepon + password.
     */
    public function rules(): array
    {
        return [
            'email' => ['nullable', 'required_without:phone', 'email'],
            'phone' => ['nullable', 'required_without:email', 'regex:/^62[0-9]{8,13}$/'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($this->filled('email') && $this->filled('phone')) {
                $validator->errors()->add('login', 'Gunakan salah satu: email atau nomor telepon, tidak boleh keduanya.');
            }
        });
    }

    public function messages(): array
    {
        return [
            'email.required_without' => 'Isi email atau nomor telepon.',
            'phone.required_without' => 'Isi email atau nomor telepon.',
            'phone.regex' => 'Format nomor telepon tidak valid.',
        ];
    }
}
