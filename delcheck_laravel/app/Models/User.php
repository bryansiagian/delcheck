<?php

namespace App\Models;

use App\Support\NomorTelepon;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasRoles, Notifiable, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'is_active' => 'boolean',
            'password' => 'hashed',
        ];
    }

    /** Email selalu disimpan huruf kecil. */
    protected function email(): Attribute
    {
        return Attribute::make(
            set: fn (?string $nilai) => $nilai === null ? null : mb_strtolower(trim($nilai)),
        );
    }

    /** Telepon selalu disimpan ternormalisasi (62xxxxxxxxxx). */
    protected function phone(): Attribute
    {
        return Attribute::make(
            set: fn (?string $nilai) => NomorTelepon::normalisasi($nilai),
        );
    }

    public function retailer(): HasOne
    {
        return $this->hasOne(Retailer::class);
    }
}
