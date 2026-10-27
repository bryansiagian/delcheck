<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SalesAssignment extends Model
{
    protected $table = 'sales_assignments';

    protected $fillable = [
        'sales_id',
        'retailer_id',
        'ditugaskan_oleh',
        'mulai',
        'selesai',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'mulai' => 'date',
            'selesai' => 'date',
            'is_active' => 'boolean',
        ];
    }

    public function sales(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sales_id');
    }

    public function retailer(): BelongsTo
    {
        return $this->belongsTo(Retailer::class);
    }
}
